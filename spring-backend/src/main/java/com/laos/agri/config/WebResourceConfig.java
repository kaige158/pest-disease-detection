package com.laos.agri.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

/**
 * 上传文件对外访问 —— 把磁盘目录挂到 /uploads/**
 *
 * <p>为什么必须显式挂：识别记录里的 {@code image_url} 是
 * {@code /uploads/recognition/xxx.jpg}，但 Spring Boot 默认只把 classpath 静态资源
 * 和少数目录暴露出去，**磁盘上的 uploads 目录不在其中** ——
 * 结果是数据库里有图、APP 打开却是 404。
 *
 * <p>安全：只映射 uploads 根目录，不做目录列举；
 * 上传文件名由服务端生成（rec_xxxxxxxx.jpg），用户无法指定路径。
 */
@Configuration
public class WebResourceConfig implements WebMvcConfigurer {

    private static final Logger log = LoggerFactory.getLogger(WebResourceConfig.class);

    private final Path uploadBase;

    public WebResourceConfig(
            @Value("${app.storage.upload-dir:./uploads}") String uploadDir) {
        this.uploadBase = Paths.get(uploadDir).toAbsolutePath().normalize();
    }

    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        try {
            Files.createDirectories(uploadBase);
        } catch (Exception e) {
            log.warn("上传目录创建失败（图片可能无法访问）: {} ({})", uploadBase, e.getMessage());
        }
        // file: 前缀表示磁盘路径；结尾斜杠不能少，否则会被当成单个文件
        String location = uploadBase.toUri().toString();
        registry.addResourceHandler("/uploads/**")
                .addResourceLocations(location)
                .setCachePeriod(3600);
        log.info("上传文件访问已挂载: /uploads/** → {}", uploadBase);
    }
}
