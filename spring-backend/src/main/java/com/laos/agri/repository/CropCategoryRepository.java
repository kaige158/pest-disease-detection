package com.laos.agri.repository;

import com.laos.agri.entity.CropCategory;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface CropCategoryRepository extends JpaRepository<CropCategory, Integer> {
    List<CropCategory> findByVersionOrderBySortOrder(String version);
}
