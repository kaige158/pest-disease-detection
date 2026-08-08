package com.laos.agri.repository;

import com.laos.agri.entity.Crop;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface CropRepository extends JpaRepository<Crop, Integer> {
    List<Crop> findByVersionAndIsActiveTrue(String version);
    List<Crop> findByCategoryIdAndIsActiveTrue(Integer categoryId);
}
