package com.aiid.aidoc.config;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Component;

import javax.sql.DataSource;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.sql.Connection;
import java.sql.Statement;
import java.util.stream.Collectors;

/**
 * 数据库初始化器
 *
 * 功能：
 * 1. 应用启动时自动执行数据库初始化脚本
 * 2. 支持幂等操作，可重复执行
 * 3. 替代 Flyway，简化数据库版本管理
 *
 * 配置：
 * - app.database.init.enabled: 是否启用初始化（默认 true）
 * - 开发环境建议启用，生产环境建议禁用（手动初始化）
 *
 * @author ArchSpec Team
 * @since 2.0.0
 */
@Component
@Slf4j
public class DatabaseInitializer implements ApplicationRunner {

    @Autowired
    private DataSource dataSource;

    @Value("${app.database.init.enabled:true}")
    private boolean initEnabled;

    @Override
    public void run(ApplicationArguments args) throws Exception {
        if (!initEnabled) {
            log.info("Database initialization is disabled (app.database.init.enabled=false)");
            return;
        }

        log.info("Starting database initialization...");

        try (Connection conn = dataSource.getConnection()) {
            // 执行 schema 初始化
            log.info("Executing schema initialization script...");
            executeSqlFile(conn, "db/init-schema.sql");
            log.info("Schema initialization completed");

            // 执行数据初始化
            log.info("Executing data initialization script...");
            executeSqlFile(conn, "db/init-data.sql");
            log.info("Data initialization completed");

            log.info("Database initialization completed successfully!");
        } catch (Exception e) {
            log.error("Database initialization failed: {}", e.getMessage(), e);
            throw new RuntimeException("Failed to initialize database", e);
        }
    }

    /**
     * 执行 SQL 文件
     *
     * @param conn 数据库连接
     * @param resourcePath 资源路径
     * @throws Exception 执行异常
     */
    private void executeSqlFile(Connection conn, String resourcePath) throws Exception {
        ClassPathResource resource = new ClassPathResource(resourcePath);

        if (!resource.exists()) {
            log.warn("SQL file not found: {}", resourcePath);
            return;
        }

        // 读取 SQL 文件内容
        String sql;
        try (BufferedReader reader = new BufferedReader(
                new InputStreamReader(resource.getInputStream(), StandardCharsets.UTF_8))) {
            sql = reader.lines().collect(Collectors.joining("\n"));
        }

        // 执行 SQL
        try (Statement stmt = conn.createStatement()) {
            stmt.execute(sql);
        }

        log.debug("Executed SQL file: {}", resourcePath);
    }
}
