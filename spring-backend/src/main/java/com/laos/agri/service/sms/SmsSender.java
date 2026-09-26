package com.laos.agri.service.sms;

/**
 * 短信发送通道 —— 抽象出来是为了"换通道不改业务代码"
 *
 * <p>为什么需要抽象：老挝本地短信服务商与国内完全不同，
 * 开发期也不能真发短信（要钱、要资质）。业务层只依赖本接口，
 * 上线时换一个实现类即可，登录/注册逻辑不动。
 *
 * <p>已提供的实现：
 * <ul>
 *   <li>{@link LoggingSmsSender} —— 开发/演示：验证码只写日志，不真发</li>
 * </ul>
 * 接入真实通道时新增实现类并注册为 Bean（或按 `app.sms.provider` 选择）。
 */
public interface SmsSender {

    /**
     * 发送验证码
     *
     * @param countryCode 国家区号（856/86/66…），用于选择通道/路由
     * @param phone       本地号码
     * @param code        验证码明文（实现方负责拼装短信文案）
     * @return 发送结果
     */
    SendResult send(String countryCode, String phone, String code);

    /** 通道名，用于日志与后台展示 */
    String providerName();

    /** 发送结果 */
    record SendResult(boolean success, String message) {
        public static SendResult ok(String message) { return new SendResult(true, message); }
        public static SendResult fail(String message) { return new SendResult(false, message); }
    }
}
