package com.laos.agri.service;

import com.laos.agri.dto.PageData;
import com.laos.agri.entity.Crop;
import com.laos.agri.entity.CropCategory;
import com.laos.agri.entity.Disease;
import com.laos.agri.repository.CropCategoryRepository;
import com.laos.agri.repository.CropRepository;
import com.laos.agri.repository.DiseaseRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

/**
 * 知识库业务服务
 */
@Service
@Transactional(readOnly = true)
public class KnowledgeService {

    private final CropCategoryRepository categoryRepo;
    private final CropRepository cropRepo;
    private final DiseaseRepository diseaseRepo;

    public KnowledgeService(CropCategoryRepository categoryRepo,
                            CropRepository cropRepo,
                            DiseaseRepository diseaseRepo) {
        this.categoryRepo = categoryRepo;
        this.cropRepo = cropRepo;
        this.diseaseRepo = diseaseRepo;
    }

    /** 获取作物分类列表 */
    public List<CropCategory> getCategories(String version) {
        return categoryRepo.findByVersionOrderBySortOrder(version);
    }

    /** 获取某分类下的作物列表 */
    public List<Crop> getCropsByCategory(Integer categoryId) {
        return cropRepo.findByCategoryIdAndIsActiveTrue(categoryId);
    }

    /** 获取某版本下的所有作物 */
    public List<Crop> getAllCrops(String version) {
        return cropRepo.findByVersionAndIsActiveTrue(version);
    }

    /** 获取某作物的病虫害列表 */
    public List<Disease> getDiseasesByCrop(Integer cropId) {
        return diseaseRepo.findByCropIdAndIsActiveTrue(cropId);
    }

    /** 获取病虫害详情 */
    public Disease getDiseaseDetail(Integer diseaseId) {
        return diseaseRepo.findById(diseaseId)
                .orElseThrow(() -> new RuntimeException("病虫害不存在: " + diseaseId));
    }

    /** 全文搜索病虫害 */
    public List<Disease> searchDiseases(String version, String query) {
        return diseaseRepo.search(version, query);
    }
}
