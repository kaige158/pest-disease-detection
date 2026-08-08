package com.laos.agri.controller;

import com.laos.agri.dto.ApiResponse;
import com.laos.agri.entity.Disease;
import com.laos.agri.entity.SourceType;
import com.laos.agri.repository.DiseaseRepository;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.Map;

/**
 * 知识库管理REST API — 专家后台AJAX调用
 */
@RestController
@RequestMapping("/api/v1/admin")
public class KnowledgeAdminController {

    private final DiseaseRepository diseaseRepo;

    public KnowledgeAdminController(DiseaseRepository diseaseRepo) {
        this.diseaseRepo = diseaseRepo;
    }

    /** 新增病虫害 */
    @PostMapping("/diseases")
    public ApiResponse<Disease> createDisease(@RequestBody Map<String, Object> body) {
        Disease disease = new Disease();
        applyDiseaseFields(disease, body);
        disease.setSourceType(SourceType.TEACHER_DATA);
        disease.setApprovalStatus("approved");
        disease.setCreatedAt(LocalDateTime.now());
        disease.setUpdatedAt(LocalDateTime.now());
        disease.setIsActive(true);

        Disease saved = diseaseRepo.save(disease);
        return ApiResponse.ok("创建成功", saved);
    }

    /** 更新病虫害 */
    @PutMapping("/diseases/{id}")
    public ApiResponse<Disease> updateDisease(@PathVariable Integer id, @RequestBody Map<String, Object> body) {
        Disease disease = diseaseRepo.findById(id)
                .orElseThrow(() -> new RuntimeException("病虫害不存在: " + id));
        applyDiseaseFields(disease, body);
        disease.setUpdatedAt(LocalDateTime.now());

        Disease saved = diseaseRepo.save(disease);
        return ApiResponse.ok("更新成功", saved);
    }

    /** 删除病虫害 (软删除) */
    @DeleteMapping("/diseases/{id}")
    public ApiResponse<?> deleteDisease(@PathVariable Integer id) {
        Disease disease = diseaseRepo.findById(id)
                .orElseThrow(() -> new RuntimeException("病虫害不存在: " + id));
        disease.setIsActive(false);
        diseaseRepo.save(disease);
        return ApiResponse.ok("已删除");
    }

    private void applyDiseaseFields(Disease disease, Map<String, Object> body) {
        if (body.containsKey("nameZh")) disease.setNameZh((String) body.get("nameZh"));
        if (body.containsKey("nameLo")) disease.setNameLo((String) body.get("nameLo"));
        if (body.containsKey("scientificName")) disease.setScientificName((String) body.get("scientificName"));
        if (body.containsKey("type")) disease.setType((String) body.get("type"));
        if (body.containsKey("version")) disease.setVersion((String) body.get("version"));
        if (body.containsKey("cropId")) disease.setCropId((Integer) body.get("cropId"));
        if (body.containsKey("symptomsZh")) disease.setSymptomsZh((String) body.get("symptomsZh"));
        if (body.containsKey("symptomsLo")) disease.setSymptomsLo((String) body.get("symptomsLo"));
        if (body.containsKey("conditionsZh")) disease.setConditionsZh((String) body.get("conditionsZh"));
        if (body.containsKey("severityLevel")) disease.setSeverityLevel((String) body.get("severityLevel"));
        if (body.containsKey("tags")) disease.setTags((String) body.get("tags"));
    }
}
