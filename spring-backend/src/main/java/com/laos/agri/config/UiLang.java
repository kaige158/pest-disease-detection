package com.laos.agri.config;

import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.stereotype.Component;

/**
 * 当前界面语言（zh / lo）—— 模板中直接写 {@code th:lang="${uiLang}"}
 *
 * <p>为什么需要它：{@code @ModelAttribute} 提供的变量在 Thymeleaf 里要写成
 * {@code ${uiLang}}，但每个 @Controller 都要额外处理；注册成一个 Spring bean 后，
 * SpEL 表达式 {@code ${uiLang}} 会解析到本对象，其 {@code toString()} 即语言码，
 * 所有模板都能直接用，无需改控制器。
 *
 * <p>另外，CookieLocaleResolver 存的是 {@code Locale("lo")} 这类无国家信息的 locale，
 * 直接取 {@code #locale.language} 在部分场景会得到空串，导致
 * {@code <html lang="">} —— 而老挝文的字体选择依赖正确的 lang，所以这里统一兜底为 zh。
 */
@Component("uiLang")
public class UiLang {

    @Override
    public String toString() {
        String lang = LocaleContextHolder.getLocale().getLanguage();
        return (lang == null || lang.isBlank()) ? "zh" : lang;
    }
}
