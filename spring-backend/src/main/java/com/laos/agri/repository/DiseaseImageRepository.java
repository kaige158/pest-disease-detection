package com.laos.agri.repository;

import com.laos.agri.entity.DiseaseImage;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.List;
import java.util.Optional;

public interface DiseaseImageRepository extends JpaRepository<DiseaseImage, Long> {
    Optional<DiseaseImage> findByImageHash(String imageHash);
    List<DiseaseImage> findByDiseaseIdAndIsUsableTrue(Integer diseaseId);

    @Query("SELECT di FROM DiseaseImage di WHERE di.isUsable = true AND di.dataGrade IN ('S','A')")
    List<DiseaseImage> findTrainingQualityImages();

    @Query(value = "SELECT COUNT(*) FROM disease_image WHERE version = :version AND is_usable = true",
           nativeQuery = true)
    long countUsableByVersion(@Param("version") String version);
}
