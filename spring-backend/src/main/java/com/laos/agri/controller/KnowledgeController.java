package com.laos.agri.controller;

import com.laos.agri.dto.ApiResponse;
import com.laos.agri.dto.PageData;
import com.laos.agri.entity.*;
import com.laos.agri.service.KnowledgeService;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * 知识库API — 供Flutter APP调用
 */
@RestController
@RequestMapping("/api/v1/knowledge")
public class KnowledgeController {

    private final KnowledgeService knowledgeService;

    public KnowledgeController(KnowledgeService knowledgeService) {
        this.knowledgeService = knowledgeService;
    }

    /** 获取作物分类 */
    @GetMapping("/categories")
    public ApiResponse<List<CropCategory>> getCategories(
            @RequestParam(defaultValue = "vegetable") String version) {
        return ApiResponse.ok(knowledgeService.getCategories(version));
    }

    /** 获取某分类下的作物 */
    @GetMapping("/crops")
    public ApiResponse<List<Crop>> getCrops(
            @RequestParam(required = false) Integer categoryId,
            @RequestParam(defaultValue = "vegetable") String version) {
        if (categoryId != null) {
            return ApiResponse.ok(knowledgeService.getCropsByCategory(categoryId));
        }
        return ApiResponse.ok(knowledgeService.getAllCrops(version));
    }

    /** 获取某作物的病虫害列表 */
    @GetMapping("/crops/{cropId}/diseases")
    public ApiResponse<List<Disease>> getDiseasesByCrop(@PathVariable Integer cropId) {
        return ApiResponse.ok(knowledgeService.getDiseasesByCrop(cropId));
    }

    /** 病虫害详情 */
    @GetMapping("/diseases/{diseaseId}")
    public ApiResponse<Disease> getDiseaseDetail(@PathVariable Integer diseaseId) {
        return ApiResponse.ok(knowledgeService.getDiseaseDetail(diseaseId));
    }

    /** 搜索病虫害 */
    @GetMapping("/search")
    public ApiResponse<List<Disease>> search(
            @RequestParam(defaultValue = "vegetable") String version,
            @RequestParam String q) {
        return ApiResponse.ok(knowledgeService.searchDiseases(version, q));
    }
}
