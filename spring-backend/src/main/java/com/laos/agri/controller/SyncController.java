package com.laos.agri.controller;

import com.laos.agri.dto.ApiResponse;
import com.laos.agri.entity.Disease;
import com.laos.agri.entity.KnowledgeArticle;
import com.laos.agri.entity.LanguageResource;
import com.laos.agri.repository.DiseaseRepository;
import com.laos.agri.repository.KnowledgeArticleRepository;
import org.springframework.data.domain.PageRequest;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * 离线数据同步API — Flutter端离线知识库增量更新
 */
@RestController
@RequestMapping("/api/v1/sync")
public class SyncController {

    private final DiseaseRepository diseaseRepo;
    private final KnowledgeArticleRepository articleRepo;

    public SyncController(DiseaseRepository diseaseRepo, KnowledgeArticleRepository articleRepo) {
        this.diseaseRepo = diseaseRepo;
        this.articleRepo = articleRepo;
    }

    /** 获取同步版本号 */
    @GetMapping("/version")
    public ApiResponse<Map<String, Object>> getSyncVersion(
            @RequestParam(defaultValue = "vegetable") String version) {
        long count = diseaseRepo.count();
        return ApiResponse.ok(Map.of(
            "data_version", "v1.0",
            "disease_count", count,
            "last_updated", LocalDateTime.now().toString(),
            "min_app_version", "1.0.0"
        ));
    }

    /** 批量获取病虫害数据(用于离线包更新) */
    @GetMapping("/diseases")
    public ApiResponse<List<Map<String, Object>>> syncDiseases(
            @RequestParam(defaultValue = "vegetable") String version,
            @RequestParam(defaultValue = "0") int sinceId) {
        List<Disease> diseases = diseaseRepo.findAll();
        List<Map<String, Object>> result = diseases.stream()
                .filter(d -> d.getId() > sinceId && d.getIsActive())
                .map(d -> {
                    Map<String, Object> m = new HashMap<>();
                    m.put("id", d.getId());
                    m.put("version", d.getVersion());
                    m.put("name_zh", d.getNameZh() != null ? d.getNameZh() : "");
                    m.put("name_lo", d.getNameLo() != null ? d.getNameLo() : "");
                    m.put("type", d.getType() != null ? d.getType() : "disease");
                    m.put("severity", d.getSeverityLevel() != null ? d.getSeverityLevel() : "moderate");
                    m.put("symptoms_zh", d.getSymptomsZh() != null ? d.getSymptomsZh() : "");
                    m.put("symptoms_lo", d.getSymptomsLo() != null ? d.getSymptomsLo() : "");
                    m.put("conditions_zh", d.getConditionsZh() != null ? d.getConditionsZh() : "");
                    m.put("crop_id", d.getCropId());
                    m.put("tags", d.getTags() != null ? d.getTags() : "");
                    m.put("image_count", d.getImageCount());
                    return m;
                })
                .collect(Collectors.toList());
        return ApiResponse.ok(result);
    }

    /** 批量获取知识库文章 */
    @GetMapping("/articles")
    public ApiResponse<List<Map<String, Object>>> syncArticles(
            @RequestParam(defaultValue = "vegetable") String version,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "100") int size) {
        var pageData = articleRepo.findByVersionAndIsPublishedTrue(version, PageRequest.of(page, size));
        List<Map<String, Object>> result = pageData.getContent().stream()
                .map(a -> {
                    Map<String, Object> m = new HashMap<>();
                    m.put("id", a.getId());
                    m.put("title_zh", a.getTitleZh() != null ? a.getTitleZh() : "");
                    m.put("title_lo", a.getTitleLo() != null ? a.getTitleLo() : "");
                    m.put("content_zh", a.getContentZh() != null ? a.getContentZh() : "");
                    m.put("content_lo", a.getContentLo() != null ? a.getContentLo() : "");
                    m.put("article_type", a.getArticleType());
                    m.put("crop_id", a.getCropId());
                    m.put("disease_id", a.getDiseaseId());
                    m.put("tags", a.getTags() != null ? a.getTags() : "");
                    return m;
                })
                .collect(Collectors.toList());
        return ApiResponse.ok(result);
    }
}
