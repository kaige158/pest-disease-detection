package com.laos.agri.controller;

import com.laos.agri.dto.ApiResponse;
import com.laos.agri.repository.DiagnosisRecordRepository;
import com.laos.agri.repository.DiseaseImageRepository;
import com.laos.agri.repository.DiseaseRepository;
import com.laos.agri.service.EvaluationService;
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
    private final DiseaseRepository diseaseRepo;
    private final DiseaseImageRepository imageRepo;
    private final EvaluationService evaluationService;

    public AdminController(DiagnosisRecordRepository diagnosisRepo,
                           DiseaseRepository diseaseRepo,
                           DiseaseImageRepository imageRepo,
                           EvaluationService evaluationService) {
        this.diagnosisRepo = diagnosisRepo;
        this.diseaseRepo = diseaseRepo;
        this.imageRepo = imageRepo;
        this.evaluationService = evaluationService;
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

    /** 获取诊断详情（用于审核） */
    @GetMapping("/review/detail/{diagnosisId}")
    public ApiResponse<?> getReviewDetail(@PathVariable Long diagnosisId) {
        var record = diagnosisRepo.findById(diagnosisId)
                .orElseThrow(() -> new RuntimeException("诊断记录不存在"));
        return ApiResponse.ok(record);
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
        record.setReviewedBy(toLong(review.get("reviewer_id")));
        record.setReviewedAt(java.time.LocalDateTime.now());

        if ("corrected".equals(action)) {
            record.setExpertDiseaseId(toInteger(review.get("corrected_disease_id")));
        }

        record.setStatus("reviewed");
        diagnosisRepo.save(record);

        return ApiResponse.ok("审核完成");
    }

    /** 用户反馈的不正确记录列表（需要优先审核） */
    @GetMapping("/review/disputed")
    public ApiResponse<?> getDisputedRecords(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        var pageData = diagnosisRepo.findAll(
                org.springframework.data.domain.PageRequest.of(page, size));
        // 过滤出 user_feedback = 'disputed' 且未审核的
        var disputed = pageData.getContent().stream()
                .filter(r -> "disputed".equals(r.getUserFeedback()) && !r.getExpertReviewed())
                .toList();
        return ApiResponse.ok(Map.of(
            "items", disputed,
            "total", disputed.size(),
            "page", page,
            "pageSize", size
        ));
    }

    // ========== 私有辅助方法 ==========

    private Long toLong(Object obj) {
        if (obj instanceof Number) return ((Number) obj).longValue();
        if (obj instanceof String) return Long.parseLong((String) obj);
        return null;
    }

    private Integer toInteger(Object obj) {
        if (obj instanceof Number) return ((Number) obj).intValue();
        if (obj instanceof String) return Integer.parseInt((String) obj);
        return null;
    }

    /** AI准确率统计 */
    @GetMapping("/evaluation/accuracy")
    public ApiResponse<?> getAccuracy(
            @RequestParam(required = false) String provider,
            @RequestParam(required = false) Integer cropId) {
        return ApiResponse.ok(evaluationService.getAccuracyStats(provider, cropId));
    }

    /** 按作物分组准确率 */
    @GetMapping("/evaluation/accuracy-by-crop")
    public ApiResponse<?> getAccuracyByCrop() {
        return ApiResponse.ok(evaluationService.getAccuracyByCrop());
    }

    /** 数据统计概览 */
    @GetMapping("/stats")
    public ApiResponse<?> getStats() {
        var counts = diagnosisRepo.countByVersion();
        long pending = diagnosisRepo.findPendingReview(PageRequest.of(0, 1000)).getTotalElements();
        return ApiResponse.ok(Map.of(
            "total_diagnoses", diagnosisRepo.count(),
            "pending_review", pending,
            "total_diseases", diseaseRepo.count(),
            "usable_images", imageRepo.countUsableByVersion("vegetable") + imageRepo.countUsableByVersion("fruit"),
            "by_version", counts
        ));
    }
}
