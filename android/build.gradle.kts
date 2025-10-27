allprojects {
    repositories {
        google()
        mavenCentral()
        // 可选镜像源（放在后面，避免覆盖官方源解析）
        maven { url = uri("https://maven.aliyun.com/repository/central") }
        maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
    }
}