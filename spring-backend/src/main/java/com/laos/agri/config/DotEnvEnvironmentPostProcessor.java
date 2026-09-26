package com.laos.agri.config;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.env.EnvironmentPostProcessor;
import org.springframework.core.Ordered;
import org.springframework.core.env.ConfigurableEnvironment;
import org.springframework.core.env.MapPropertySource;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 支持用 {@code .env} 文件注入环境变量 —— 让密钥不必写进代码或命令历史。
 *
 * <p>为什么需要：{@code JWT_SECRET} / {@code AI_KEY_SECRET} / {@code ADMIN_INIT_PASSWORD}
 * 这类密钥如果每次都靠命令行设置，很容易被写进脚本、shell 历史甚至提交到版本库。
 * 放在 {@code .env}（已在 .gitignore 中排除）更安全，也便于运维交接。
 *
 * <p>Spring Boot 原生只支持 {@code application.properties} / YAML 与真实环境变量，
 * 不认识 {@code .env}，这里用 {@link EnvironmentPostProcessor} 补上这一环。
 *
 * <p>查找顺序（先找到先用，**不覆盖已存在的真实环境变量**）：
 * <ol>
 *   <li>{@code ./spring-backend/.env}（从仓库根目录启动时）</li>
 *   <li>{@code ./.env}（从 spring-backend 目录启动时）</li>
 *   <li>{@code ../.env}（打包成 jar 放在服务器任意目录时，允许放上一级）</li>
 * </ol>
 *
 * <p>格式规则：`KEY=VALUE`，支持 `#` 注释与空行；
 * 值两侧的引号会被去掉，但**值内部保留原样**（密钥常含特殊字符）。
 */
public class DotEnvEnvironmentPostProcessor implements EnvironmentPostProcessor, Ordered {

    private static final String SOURCE_NAME = "dotenvFile";

    @Override
    public void postProcessEnvironment(ConfigurableEnvironment environment, SpringApplication application) {
        Path envFile = locateEnvFile();
        if (envFile == null) return;

        Map<String, Object> values = parse(envFile);
        if (values.isEmpty()) return;

        // addLast：真实环境变量/O命令行参数优先级更高，.env 只做兜底
        environment.getPropertySources().addLast(new MapPropertySource(SOURCE_NAME, values));
    }

    private Path locateEnvFile() {
        List<String> candidates = List.of(
                "spring-backend/.env",
                ".env",
                "../.env"
        );
        for (String c : candidates) {
            Path p = Paths.get(c).toAbsolutePath().normalize();
            if (Files.isRegularFile(p)) return p;
        }
        return null;
    }

    private Map<String, Object> parse(Path file) {
        Map<String, Object> map = new LinkedHashMap<>();
        try {
            for (String rawLine : Files.readAllLines(file, StandardCharsets.UTF_8)) {
                String line = rawLine.trim();
                if (line.isEmpty() || line.startsWith("#")) continue;

                // 允许 "export KEY=VALUE" 这种从 shell 复制过来的写法
                if (line.startsWith("export ")) line = line.substring(7).trim();

                int eq = line.indexOf('=');
                if (eq <= 0) continue;

                String key = line.substring(0, eq).trim();
                String value = line.substring(eq + 1).trim();
                if (key.isEmpty()) continue;

                // 去掉成对的引号，但保留值内部内容
                if (value.length() >= 2
                        && ((value.startsWith("\"") && value.endsWith("\""))
                            || (value.startsWith("'") && value.endsWith("'")))) {
                    value = value.substring(1, value.length() - 1);
                }
                map.put(key, value);
            }
        } catch (IOException e) {
            // 读不到就当作没有 .env，不阻断启动
            return Map.of();
        }
        return map;
    }

    @Override
    public int getOrder() {
        // 尽早执行，确保后续的配置解析能读到这些值
        return Ordered.HIGHEST_PRECEDENCE + 20;
    }
}
