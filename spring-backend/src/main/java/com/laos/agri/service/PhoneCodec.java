package com.laos.agri.service;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Pattern;

/**
 * 国际手机号解析 —— 区号与号码分离存储
 *
 * <p>为什么不能只用一个 phone 字段：平台面向老挝，但用户会跨国流动
 * （中国技术员、泰国客商、越南边民），业务上还需要按国家统计用户。
 * 存储上把「区号」与「本地号码」分开，展示与校验都更可靠。
 *
 * <p>历史数据兼容：{@code countryCode} 为空表示早期数据（phone 里存了完整号码），
 * 登录与展示按原样处理，不做拆分，避免影响老账号。
 */
public final class PhoneCodec {

    private PhoneCodec() {}

    /** 支持的国家/地区（顺序即界面下拉顺序：老挝优先） */
    public record Country(String code, String zhName, String loName, String flag,
                          /** 本地号码的书写形态正则；太长/太短都算不匹配 */
                          String localPattern) {
        public String name(String lang) {
            return "lo".equalsIgnoreCase(lang) ? loName : zhName;
        }
    }

    public static final List<Country> COUNTRIES = List.of(
            // 老挝手机号实际就是 020 / 030 开头（020 最常见），固定电话 021。
            // 早期写成宽松的 "0?2[0-9]{8,9}" 会把泰国 0812... 也匹配上，故收紧。
            new Country("856", "老挝", "ລາວ", "🇱🇦", "0?2[0-9]{7,8}"),
            new Country("86", "中国", "ຈີນ", "🇨🇳", "1[3-9][0-9]{9}"),
            new Country("66", "泰国", "ໄທ", "🇹🇭", "0?[689][0-9]{8}"),
            new Country("84", "越南", "ຫວຽດນາມ", "🇻🇳", "0?[35789][0-9]{8}"),
            new Country("855", "柬埔寨", "ກຳປູເຈຍ", "🇰🇭", "0?[1-9][0-9]{7,8}"),
            new Country("95", "缅甸", "ມຽນມາ", "🇲🇲", "0?9[0-9]{7,9}"),
            new Country("1", "美国/加拿大", "ອາເມລິກາ", "🇺🇸", "[2-9][0-9]{9}"),
            new Country("81", "日本", "ຍີ່ປຸ່ນ", "🇯🇵", "0?[789]0[0-9]{8}"),
            new Country("82", "韩国", "ເກົາຫຼີ", "🇰🇷", "0?1[0-9]{8,9}"),
            new Country("61", "澳大利亚", "ອອສເຕຣເລຍ", "🇦🇺", "0?4[0-9]{8}")
    );

    /** 默认国家（平台主战场） */
    public static final String DEFAULT_COUNTRY_CODE = "856";

    /**
     * 系统账号白名单 —— 不含手机号的运维账号。
     * 只允许这些固定账号绕过手机号校验，避免非法输入被当作账号注册。
     */
    private static final java.util.Set<String> SYSTEM_ACCOUNTS = java.util.Set.of("admin");

    /** 本地号码允许长度区间（去掉空格/连字符后的纯数字位数） */
    private static final int MIN_LOCAL_DIGITS = 6;
    private static final int MAX_LOCAL_DIGITS = 15;

    /**
     * 自动识别区号时要求的区号最小长度。
     *
     * <p>为什么是 3：美国/加拿大 +1、泰国 +66、越南 +84 等短区号
     * 与本地号码的首位数字无法区分（如 13900001111 会被误读成「+1 39…」）。
     * 因此无 {@code +} 前缀时只自动识别 3 位区号（856 老挝、855 柬埔寨），
     * 短区号必须由用户显式选择或写成 {@code +86...}。
     */
    private static final int MIN_PREFIX_LEN_FOR_AUTODETECT = 3;

    private static final Pattern COUNTRY_CODE = Pattern.compile("^[0-9]{1,4}$");

    /** 号码非法 */
    public static class InvalidPhoneException extends RuntimeException {
        public InvalidPhoneException(String message) { super(message); }
    }

    /** 解析结果：规范化后的区号 + 本地号码 */
    public record ParsedPhone(String countryCode, String localNumber) {
        /** 完整 E.164 形式（不带 + 号），用于日志与跨系统传递 */
        public String fullNumber() {
            return countryCode == null || countryCode.isBlank()
                    ? localNumber
                    : countryCode + localNumber;
        }
    }

    public static boolean isSupportedCountry(String code) {
        if (code == null) return false;
        return COUNTRIES.stream().anyMatch(c -> c.code().equals(code.trim()));
    }

    public static Country country(String code) {
        if (code == null) return COUNTRIES.get(0);
        return COUNTRIES.stream()
                .filter(c -> c.code().equals(code.trim()))
                .findFirst()
                .orElse(COUNTRIES.get(0));
    }

    /**
     * 规范化输入。
     *
     * <p>国家识别优先级（这个顺序很关键，否则会出现"中国号码被标成 +856"）：
     * <ol>
     *   <li><b>号码自带前缀</b>（{@code +86...} / {@code 861...}）→ 以后缀识别为准，
     *       因为用户写出来的国家信息比界面默认值可靠</li>
     *   <li>调用方显式指定的区号（APP 里用户选的国家）</li>
     *   <li>兜底默认国家（老挝）</li>
     * </ol>
     *
     * <p>注意：<b>不再假设"没传区号就是老挝"</b>。
     * 老挝本地号码（020...）与泰国（0...）都可能带前导 0，
     * 这种情况必须由调用方显式给出国家，见 {@link #isAmbiguous}。
     */
    public static ParsedPhone parse(String rawCountryCode, String rawPhone) {
        if (rawPhone == null || rawPhone.isBlank()) {
            throw new InvalidPhoneException("请输入手机号");
        }
        String phone = rawPhone.trim();

        // 系统账号：仅限白名单里的运维账号（如 admin），
        // 不能放宽成"任意字母串"，否则非法输入会被当成合法账号注册进来
        if (SYSTEM_ACCOUNTS.contains(phone.toLowerCase())) {
            return new ParsedPhone(null, phone.toLowerCase());
        }

        String digits = phone.replaceAll("[\\s\\-()]", "");
        boolean hadPlus = digits.startsWith("+");
        if (hadPlus) digits = digits.substring(1);

        String cc = rawCountryCode == null ? "" : rawCountryCode.trim().replaceAll("[^0-9]", "");

        // ① 号码自带国际前缀（+86 / +856...）→ 一律以此为准（用户已明确写出国家）
        if (hadPlus) {
            ParsedPhone byPrefix = matchExplicitPlus(digits);
            if (byPrefix != null) return byPrefix;
            throw new InvalidPhoneException("无法识别该国际号码的区号，请手动选择国家");
        }

        // ② 有显式区号时，先剥掉号码里可能重复写上的区号（+856 写成 85620...）
        if (!cc.isEmpty()) {
            if (!COUNTRY_CODE.matcher(cc).matches() || !isSupportedCountry(cc)) {
                throw new InvalidPhoneException("不支持的国家区号：" + cc);
            }
            String body = digits;
            if (body.startsWith(cc) && body.length() > cc.length() + MIN_LOCAL_DIGITS - 1) {
                body = body.substring(cc.length());
            }
            return validate(cc, body);
        }

        // ③ 没有区号也没有 + ：先按号码书写形态识别国家，
        //    识别不出再退回"默认国家"，绝不盲目按区号前缀猜
        //    （否则 13900001111 会被误读成美国 +1）
        CountryDetection detection = detect(digits, DEFAULT_COUNTRY_CODE);
        ParsedPhone byPrefix = matchByPrefix(digits);
        if (byPrefix != null) return byPrefix;
        if (!detection.isGuessed()) {
            return validate(detection.countryCode(), digits);
        }

        // ④ 兜底：按默认国家处理（用于老客户端/老数据兼容）
        return validate(DEFAULT_COUNTRY_CODE, digits);
    }

    /**
     * 国家识别结果
     *
     * @param countryCode 识别出的区号
     * @param confidence  识别把握：explicit=用户写明 / matched=号码格式吻合 / guessed=按默认国家兜底
     * @param others      同样吻合的其它国家（用于"多个可能"时提示用户确认）
     */
    public record CountryDetection(String countryCode, String confidence, List<String> others) {
        public boolean isGuessed() { return "guessed".equals(confidence); }
    }

    /**
     * 识别号码属于哪个国家 —— 用「号码书写形态」比对，而不是简单前缀匹配。
     *
     * <p>为什么不能用前缀：{@code 1}（美国）是合法区号，{@code 13900001111}
     * 会被误读成「+1 3900001111」。改用各国本地号码正则后，
     * 中国号码（1 开头 11 位）与老挝号码（02/05/07 开头 9~10 位）能明确区分。
     *
     * @param preferred 调用方倾向的国家（通常是用户在下拉里选的），用于同等匹配下优先
     */
    public static CountryDetection detect(String rawPhone, String preferred) {
        String digits = rawPhone == null ? "" : rawPhone.trim().replaceAll("[\\s\\-()]", "");
        if (digits.startsWith("+")) {
            String rest = digits.substring(1);
            for (Country c : COUNTRIES.stream()
                    .sorted((a, b) -> Integer.compare(b.code().length(), a.code().length()))
                    .toList()) {
                if (!rest.startsWith(c.code())) continue;
                String body = rest.substring(c.code().length());
                if (body.length() >= MIN_LOCAL_DIGITS) {
                    return new CountryDetection(c.code(), "explicit", List.of());
                }
            }
            return new CountryDetection(preferred, "guessed", List.of());
        }

        List<String> matches = COUNTRIES.stream()
                .filter(c -> digits.matches(c.localPattern()))
                .map(Country::code)
                .toList();

        if (matches.isEmpty()) {
            // 形态对不上任何国家 → 交给调用方按用户选择处理，并标为不确定
            return new CountryDetection(preferred, "guessed", List.of());
        }
        if (preferred != null && matches.contains(preferred)) {
            // 用户选的与号码形态一致 → 最可信
            return new CountryDetection(preferred, "matched",
                    matches.stream().filter(m -> !m.equals(preferred)).toList());
        }
        if (matches.size() == 1) {
            // 唯一吻合：即使用户没选/选错，也应以号码为准
            return new CountryDetection(matches.get(0), "matched", List.of());
        }
        // 多个国家都吻合 → 优先用户选择；用户没选时取默认国家（老挝）并告知还有其它可能。
        // 注意 others 非空表示"号码形态存在歧义"，界面应提示用户确认国家，
        // 而不是默默按某个国家建档 —— 这正是"中国号码被标成 +856"的根因。
        // （用 final 局部变量承接，避免在 lambda 里引用被重新赋值的变量）
        final List<String> candidates = matches;
        String primary = (preferred != null && !preferred.isBlank()) ? preferred : DEFAULT_COUNTRY_CODE;
        if (!candidates.contains(primary)) primary = candidates.get(0);
        final String chosen = primary;
        return new CountryDetection(chosen, "matched",
                candidates.stream().filter(m -> !m.equals(chosen)).toList());
    }

    /**
     * 按已知国家区号匹配号码前缀。
     *
     * <p>匹配条件（三者同时满足才认，宁可认不出也不猜错）：
     * <ol>
     *   <li>号码以该区号开头</li>
     *   <li>剩余位数落在本地号码长度区间内</li>
     *   <li><b>该区号本身长度 ≥ {@value #MIN_PREFIX_LEN_FOR_AUTODETECT}</b></li>
     * </ol>
     *
     * <p>第 3 条是踩坑后加的：{@code 1}（美国/加拿大）本身是合法区号，
     * 于是 {@code 13900001111} 会被误读成「美国 + 39…」。
     * 无 {@code +} 前缀时只认 3 位区号（856 老挝 / 855 柬埔寨），
     * 其余交给 {@link #detect} 按号码形态判断。
     */
    private static ParsedPhone matchByPrefix(String digits) {
        for (Country c : COUNTRIES.stream()
                .sorted((a, b) -> Integer.compare(b.code().length(), a.code().length()))
                .toList()) {
            if (c.code().length() < MIN_PREFIX_LEN_FOR_AUTODETECT) continue;
            if (!digits.startsWith(c.code())) continue;
            String rest = digits.substring(c.code().length());
            if (rest.length() >= MIN_LOCAL_DIGITS && rest.length() <= MAX_LOCAL_DIGITS) {
                return new ParsedPhone(c.code(), rest);
            }
        }
        return null;
    }

    /**
     * 带 {@code +} 前缀时按最长匹配识别区号（用户已明确写出国家，可以放宽长度限制）
     */
    private static ParsedPhone matchExplicitPlus(String digits) {
        for (Country c : COUNTRIES.stream()
                .sorted((a, b) -> Integer.compare(b.code().length(), a.code().length()))
                .toList()) {
            if (!digits.startsWith(c.code())) continue;
            String rest = digits.substring(c.code().length());
            if (rest.length() >= MIN_LOCAL_DIGITS && rest.length() <= MAX_LOCAL_DIGITS) {
                return new ParsedPhone(c.code(), rest);
            }
        }
        return null;
    }

    /**
     * 号码是否"国家不明确" —— 需要界面强制用户选择国家。
     *
     * <p>典型情况：老挝本地写作 {@code 02055551234}，泰国写作 {@code 0812345678}，
     * 都带前导 0，光看号码无法区分。此时不应猜，而应让用户明示。
     */
    public static boolean isAmbiguous(String rawPhone) {
        if (rawPhone == null) return true;
        String digits = rawPhone.trim().replaceAll("[\\s\\-()]", "");
        if (digits.startsWith("+")) return false;          // 用户已写明国际区号
        String cc = "";
        return matchByPrefix(digits) == null || digits.startsWith("0");
    }

    private static ParsedPhone validate(String countryCode, String localDigits) {
        String local = localDigits.replaceAll("[^0-9]", "");
        if (local.length() < MIN_LOCAL_DIGITS || local.length() > MAX_LOCAL_DIGITS) {
            throw new InvalidPhoneException(
                    "手机号长度不正确（当前 " + local.length() + " 位，应为 "
                            + MIN_LOCAL_DIGITS + "~" + MAX_LOCAL_DIGITS + " 位）");
        }
        return new ParsedPhone(countryCode, local);
    }

    /**
     * 登录查找用的候选号码 —— 依次尝试，兼容历史数据
     *
     * <p>新数据：phone = 本地号码（区号单独存）
     * <p>历史数据：phone = 完整号码（区号为空，可能是 85620... 或 020...）
     *
     * <p><b>带 0 / 不带 0 必须互相能查到</b>：老挝人习惯写 {@code 02055550001}，
     * 而系统展示时用的是 {@code +856 02055550001}（{@link #display} 会补 0），
     * 库里两种形态都可能存在。若只加"补 0"而不加"去 0"，
     * 一个用 {@code 2055550001} 注册的账号，用户改用 {@code 02055550001} 登录时
     * 就会查不到 —— 结果是**又注册出一个重复账号**，数据从此分裂。
     */
    public static List<String> lookupCandidates(ParsedPhone parsed) {
        Map<String, Boolean> ordered = new LinkedHashMap<>();
        ordered.put(parsed.localNumber(), true);
        if (parsed.countryCode() != null) {
            ordered.put(parsed.countryCode() + parsed.localNumber(), true);
            if (parsed.localNumber().startsWith("0")) {
                // 库里可能存的是去掉前导 0 的形态（display() 就是这么显示的）
                ordered.put(parsed.localNumber().substring(1), true);
            } else {
                // 老挝本地常见写法：020xxxxxxx（保留前导 0）
                ordered.put("0" + parsed.localNumber(), true);
            }
        }
        return List.copyOf(ordered.keySet());
    }

    /** 展示用：区号 + 号码（本地号码前补 0 更符合老挝书写习惯） */
    public static String display(String countryCode, String localNumber) {
        if (localNumber == null) return "";
        if (countryCode == null || countryCode.isBlank()) return localNumber;
        if ("856".equals(countryCode) && !localNumber.startsWith("0")) {
            return "+856 0" + localNumber;
        }
        return "+" + countryCode + " " + localNumber;
    }
}
