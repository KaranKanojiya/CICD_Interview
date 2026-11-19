package cicd;

import org.springframework.beans.factory.ObjectProvider;
import org.springframework.boot.info.BuildProperties;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Which build is running? Pipelines smoke-test this after every deploy to confirm the version
 * they meant to ship is the one actually serving traffic.
 */
@RestController
public class VersionController {

    private final ObjectProvider<BuildProperties> buildProperties;

    public VersionController(ObjectProvider<BuildProperties> buildProperties) {
        this.buildProperties = buildProperties;
    }

    @GetMapping("/api/version")
    public Map<String, String> version() {
        Map<String, String> body = new LinkedHashMap<>();
        BuildProperties build = buildProperties.getIfAvailable();
        body.put("version", build != null ? build.getVersion() : "unknown");
        body.put("commit", build != null && build.get("commit") != null ? build.get("commit") : "unknown");
        body.put("builtAt", build != null && build.getTime() != null ? build.getTime().toString() : "unknown");
        return body;
    }
}
