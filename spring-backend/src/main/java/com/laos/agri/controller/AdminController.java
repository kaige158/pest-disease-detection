package com.laos.agri.controller;

import com.laos.agri.dto.ApiResponse;
import com.laos.agri.repository.DiagnosisRecordRepository;
import org.springframework.data.domain.PageRequest;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/**
 * 专家后台API — AI审核 + 数据管理 (第四阶段MVP版本)
 */
@RestController
@RequestMapping("/api/v1/admin")
public class AdminController {

    private final DiagnosisRecordRepository diagnosisRepo;

    public AdminController(DiagnosisRecordRepository diagnosisRepo) {
        this.diagnosisRepo = diagnosisRepo;
    }

    /** 获取待审核诊断列表 */
    @GetMapping("/pending-review")
    public ApiResponse<?> getPendingReview(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        var pageData = diagnosisRepo.findPendingReview(PageRequest.of(page, size));
        return ApiResponse.ok(Map.of(
            "items", pageData.getContent(),
            "total", pageData.getTotalElements(),
            "page", page,
            "pageSize", size
        ));
    }

    /** 专家审核诊断结果 */
    @PostMapping("/review/{diagnosisId}")
    public ApiResponse<?> reviewDiagnosis(
            @PathVariable Long diagnosisId,
            @RequestBody Map<String, Object> review) {

        var record = diagnosisRepo.findById(diagnosisId)
                .orElseThrow(() -> new RuntimeException("诊断记录不存在"));

        String action = (String) review.getOrDefault("action", "verified");

        record.setExpertReviewed(true);
        record.setExpertAction(action);
        record.setExpertNotes((String) review.getOrDefault("notes", ""));
        record.setReviewedBy((Long) review.get("reviewer_id"));

        if ("corrected".equals(action)) {
            record.setExpertDiseaseId((Integer) review.get("corrected_disease_id"));
        }

        record.setStatus("reviewed");
        diagnosisRepo.save(record);

        return ApiResponse.ok("审核完成");
    }

    /** 数据统计概览 */
    @GetMapping("/stats")
    public ApiResponse<?> getStats() {
        var counts = diagnosisRepo.countByVersion();
        return ApiResponse.ok(Map.of(
            "total_diagnoses", diagnosisRepo.count(),
            "by_version", counts
        ));
    }
}
