# Build stage
FROM docker.m.daocloud.io/maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app

# 配置阿里云 Maven 镜像加速
RUN mkdir -p /root/.m2 && echo '<?xml version="1.0" encoding="UTF-8"?>\
<settings><mirrors><mirror>\
<id>aliyun</id><mirrorOf>central</mirrorOf>\
<url>https://maven.aliyun.com/repository/public</url>\
</mirror></mirrors></settings>' > /root/.m2/settings.xml

COPY . .
RUN mvn clean package -DskipTests

# Run stage
FROM docker.m.daocloud.io/eclipse-temurin:17-jre-alpine
WORKDIR /app

# 创建非 root 用户
# RUN addgroup -S spring && adduser -S spring -G spring
# USER spring:spring

# 复制构建好的 jar 文件
COPY --from=build /app/ai-doc-system-rest/target/ai-doc-system-rest-1.0.0.jar app.jar

# 暴露端口
EXPOSE 8080

# 启动应用
ENTRYPOINT ["java", "-jar", "app.jar"]

