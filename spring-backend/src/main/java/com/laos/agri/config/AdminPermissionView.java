package com.laos.agri.config;

import com.laos.agri.entity.Permission;
import com.laos.agri.entity.UserRole;
import org.springframework.context.MessageSource;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 后台「角色权限说明」视图数据 —— 由 {@link Permission} 的真实规则生成文案
 *
 * <p>解决的问题（用户提出）：后台能改角色，但界面上只有"管理员/专家/农技员/农户"
 * 四个词，交付给管理员后没人知道"给某人 EXPERT 到底给了什么"。
 *
 * <p>关键设计：**说明不是另写一份文案，而是从权限矩阵生成**。
 * 如果以后有人改了 {@link Permission#of(UserRole)}，界面上的说明会自动跟着变，
 * 不会出现"界面说能改、代码却拦住"这种最难排查的不一致。
 *
 * <p>文案在这里就解析成当前语言的字符串（而不是在模板里拼 i18n 键），
 * 因为 Thymeleaf 动态键名语法容易写错且难排查；用 MessageSource 更直接。
 */
@Component
public class AdminPermissionView {

    private final MessageSource messages;

    public AdminPermissionView(MessageSource messages) {
        this.messages = messages;
    }

    /** 一行权限：名称 + 各角色是否拥有 */
    public record Row(String label, Map<String, Boolean> allow) {
        public boolean allows(RoleCard role) {
            return Boolean.TRUE.equals(allow.get(role.code()));
        }
    }

    /** 一个角色的说明卡片 */
    public record RoleCard(String code, String label, String summary,
                           List<String> can, List<String> cannot) {}

    public record View(List<Row> rows, List<RoleCard> roles) {}

    /** 按当前请求语言构建（zh / lo） */
    public View build() {
        var locale = LocaleContextHolder.getLocale();
        List<Permission.MatrixRow> matrix = Permission.matrix();

        List<RoleCard> roles = new ArrayList<>();
        List<Row> rows = new ArrayList<>();

        for (Permission.MatrixRow mr : matrix) {
            Map<String, Boolean> allow = new LinkedHashMap<>();
            for (UserRole r : UserRole.values()) {
                allow.put(r.name(), mr.allows(r));
            }
            rows.add(new Row(msg(mr.labelKey(), locale), allow));
        }

        // 角色卡片：逐个角色列出"可以做 / 不可以做"，顺序与矩阵列一致
        for (UserRole role : UserRole.values()) {
            List<String> can = new ArrayList<>();
            List<String> cannot = new ArrayList<>();
            for (Permission.MatrixRow mr : matrix) {
                (mr.allows(role) ? can : cannot).add(msg(mr.labelKey(), locale));
            }
            roles.add(new RoleCard(
                    role.name(),
                    msg("role." + role.name(), locale),
                    msg("role.desc." + role.name(), locale),
                    can, cannot));
        }

        return new View(rows, roles);
    }

    private String msg(String key, java.util.Locale locale) {
        try {
            return messages.getMessage(key, null, locale);
        } catch (org.springframework.context.NoSuchMessageException e) {
            // 缺翻译时宁可显示键名，也不要显示空白 —— 空白在界面上根本发现不了
            return "!" + key;
        }
    }
}
