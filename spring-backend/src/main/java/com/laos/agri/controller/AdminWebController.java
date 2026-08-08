package com.laos.agri.controller;

import com.laos.agri.repository.CropRepository;
import com.laos.agri.repository.DiagnosisRecordRepository;
import com.laos.agri.repository.DiseaseImageRepository;
import com.laos.agri.repository.DiseaseRepository;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;

/**
 * 专家后台Web页面控制器 (Thymeleaf服务端渲染)
 * 老师通过浏览器直接访问，不需要额外前端项目
 */
@Controller
@RequestMapping("/admin")
public class AdminWebController {

    private final DiagnosisRecordRepository diagnosisRepo;
    private final DiseaseRepository diseaseRepo;
    private final DiseaseImageRepository imageRepo;
    private final CropRepository cropRepo;

    public AdminWebController(DiagnosisRecordRepository diagnosisRepo,
                              DiseaseRepository diseaseRepo,
                              DiseaseImageRepository imageRepo,
                              CropRepository cropRepo) {
        this.diagnosisRepo = diagnosisRepo;
        this.diseaseRepo = diseaseRepo;
        this.imageRepo = imageRepo;
        this.cropRepo = cropRepo;
    }

    /** 仪表盘首页 */
    @GetMapping("/dashboard")
    public String dashboard(Model model) {
        long totalDiagnoses = diagnosisRepo.count();
        long pendingReview = diagnosisRepo.findPendingReview(PageRequest.of(0, 1000)).getTotalElements();
        long totalDiseases = diseaseRepo.count();
        long usableImages = imageRepo.countUsableByVersion("vegetable") + imageRepo.countUsableByVersion("fruit");

        model.addAttribute("totalDiagnoses", totalDiagnoses);
        model.addAttribute("pendingReview", pendingReview);
        model.addAttribute("totalDiseases", totalDiseases);
        model.addAttribute("usableImages", usableImages);
        model.addAttribute("currentPage", "dashboard");
        return "admin/dashboard";
    }

    /** AI审核中心 */
    @GetMapping("/review")
    public String reviewCenter(Model model) {
        var pendingPage = diagnosisRepo.findPendingReview(
                PageRequest.of(0, 50, Sort.by(Sort.Direction.DESC, "createdAt")));
        model.addAttribute("pendingList", pendingPage.getContent());
        model.addAttribute("pendingCount", pendingPage.getTotalElements());
        model.addAttribute("currentPage", "review");
        return "admin/review";
    }

    /** 知识库管理 */
    @GetMapping("/knowledge")
    public String knowledgeManagement(Model model) {
        var crops = cropRepo.findAll();
        var diseases = diseaseRepo.findAll();
        model.addAttribute("crops", crops);
        model.addAttribute("diseases", diseases);
        model.addAttribute("currentPage", "knowledge");
        return "admin/knowledge";
    }

    /** 数据统计 */
    @GetMapping("/stats")
    public String statistics(Model model) {
        model.addAttribute("currentPage", "stats");
        return "admin/stats";
    }

    /** 登录页 */
    @GetMapping("/login")
    public String login() {
        return "admin/login";
    }
}
