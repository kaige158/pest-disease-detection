package com.laos.agri;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;

/**
 * 中老双语农业病虫害诊断与知识服务平台 — 主入口
 *
 * <p>项目定位: 农业数字化服务平台，非简单AI识别APP。
 * 面向东盟国际农业场景，由农业专家运营，持续积累数据资产。</p>
 */
@SpringBootApplication
@EnableJpaAuditing
public class AgriPlatformApplication {

    public static void main(String[] args) {
        SpringApplication.run(AgriPlatformApplication.class, args);
    }
}
