package com.laos.agri.service.sms;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/**
 * 开发/演示用短信通道 —— 只打印日志，不真正发送
 *
 * <p>为什么默认用它：开发期不该产生短信费用，也不该因为拿不到服务商资质就阻塞开发。
 * 但它**必须让人一眼看出"这是没真发"**，否则容易出现
 * "以为上线了其实验证码根本没发出去"的事故 —— 所以日志带醒目 WARN 前缀。
 *
 * <p>生产接入：把 {@code app.sms.provider} 设为真实通道（如 lao-telecom），
 * 并实现对应的 {@link SmsSender} Bean；本类通过
 * {@code @ConditionalOnProperty(matchIfMissing = false)} 自动退出，
 * 不会误用。
 */
@Component
@ConditionalOnProperty(name = "app.sms.provider", havingValue = "log", matchIfMissing = true)
public class LoggingSmsSender implements SmsSender {

    private static final Logger log = LoggerFactory.getLogger(LoggingSmsSender.class);

    @Override
    public SendResult send(String countryCode, String phone, String code) {
        String full = "+" + countryCode + " " + phone;
        log.warn("=====================================================================");
        log.warn(" [短信通道未接入] 验证码未真实发送");
        log.warn("   手机号 : {}", full);
        log.warn("   验证码 : {}", code);
        log.warn("   有效期 : 5 分钟");
        log.warn(" 如需真实发送，请配置 app.sms.provider 并实现对应 SmsSender");
        log.warn("=====================================================================");
        // 机器可读行 —— 全 ASCII，任何日志编码（UTF-8/GBK）下字节都不变，
        // 便于自动化测试稳定提取验证码，无需猜日志编码。
        log.warn(" [DEMO-SMS] code={} country={} phone={}", code, countryCode, phone);
        return SendResult.ok("验证码已生成（当前为开发通道，未真实发送短信，验证码见服务端日志）");
    }

    @Override
    public String providerName() {
        return "log";
    }
}
