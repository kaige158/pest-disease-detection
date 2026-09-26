package com.laos.agri.service;

import com.laos.agri.entity.DiagnosisRecord;
import com.laos.agri.entity.DiseaseImage;
import com.laos.agri.entity.TrainingDataset;
import com.laos.agri.entity.User;
import com.laos.agri.entity.UserRole;
import com.laos.agri.repository.DiagnosisRecordRepository;
import com.laos.agri.repository.DiseaseImageRepository;
import com.laos.agri.repository.PhoneVerificationRepository;
import com.laos.agri.repository.TrainingDatasetRepository;
import com.laos.agri.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;

/**
 * 删除用户账号 —— **只删"人"，不删"数据"**
 *
 * <p>平台的核心资产是农业数据：识别记录、图片、专家审核结论、训练数据资产。
 * 这些数据越多，模型越准，平台越有价值。用户注销/被清理时如果把这些一起删掉，
 * 等于每删一个账号就挖掉平台一块资产 —— 这是绝对不能接受的。
 *
 * <p>因此这里的策略是「账号删除 + 数据匿名保留」：
 *
 * <table border="1">
 *   <tr><th>处理</th><th>对象</th><th>说明</th></tr>
 *   <tr><td><b>删除</b></td><td>{@code core.app_user} 账号本身</td>
 *       <td>手机号、密码哈希、昵称、区号、设备记录随之消失，号码可被重新注册</td></tr>
 *   <tr><td><b>删除</b></td><td>{@code core.phone_verification} 该号码的验证码记录</td>
 *       <td>纯个人信息残留，无数据价值</td></tr>
 *   <tr><td><b>匿名保留</b></td><td>{@code core.diagnosis_record}</td>
 *       <td>清空 user_id / device_uuid / device_info，其余（作物、AI 结果、
 *           专家审核、图片、地区）保留 —— 去掉"是谁"，留下"是什么"</td></tr>
 *   <tr><td><b>保留</b></td><td>{@code extension.training_dataset} 训练数据资产</td>
 *       <td>一个字都不动，含专家已确认的标签</td></tr>
 *   <tr><td><b>保留</b></td><td>{@code extension.disease_image} 图片记录与磁盘文件</td>
 *       <td>训练与溯源的原始素材</td></tr>
 *   <tr><td><b>保留</b></td><td>{@code core.audit_log} 审计日志</td>
 *       <td>谁在什么时候删了谁，必须可追溯</td></tr>
 * </table>
 *
 * <p>为什么清 {@code device_uuid}：它是设备级持久标识，能跨账号把同一个人认出来，
 * 属于个人信息；而它对"这张叶子是什么病"没有任何价值，所以一并清掉。
 */
@Service
public class UserDeletionService {

    private static final Logger log = LoggerFactory.getLogger(UserDeletionService.class);

    private final UserRepository userRepo;
    private final DiagnosisRecordRepository diagnosisRepo;
    private final DiseaseImageRepository imageRepo;
    private final TrainingDatasetRepository trainingRepo;
    private final PhoneVerificationRepository verificationRepo;

    public UserDeletionService(UserRepository userRepo,
                               DiagnosisRecordRepository diagnosisRepo,
                               DiseaseImageRepository imageRepo,
                               TrainingDatasetRepository trainingRepo,
                               PhoneVerificationRepository verificationRepo) {
        this.userRepo = userRepo;
        this.diagnosisRepo = diagnosisRepo;
        this.imageRepo = imageRepo;
        this.trainingRepo = trainingRepo;
        this.verificationRepo = verificationRepo;
    }

    /**
     * 删除影响预览 —— 说清"删什么、留什么"
     *
     * <p>对管理员来说，最需要确认的恰恰是**保留**的那部分：
     * "删了这个人，平台的数据资产会不会少？"答案必须写在界面上。
     */
    public record Preview(
            Long userId, String nickname, String phoneMasked, String countryCode,
            String role, boolean active,
            /** 将被匿名保留的识别记录数 */
            long diagnosesKept,
            /** 将被保留的图片数（记录 + 磁盘文件都不动） */
            long imagesKept,
            /** 将被保留的训练数据资产数 */
            long trainingAssetsKept,
            /** 其中专家已确认、可用于训练的数量 */
            long trainingReadyKept,
            /** 将随账号一起删除的短信验证码记录数 */
            long verificationCodes,
            List<String> blockers) {

        public boolean deletable() {
            return blockers == null || blockers.isEmpty();
        }
    }

    /** 删除结果：删了什么、留了什么，都要能回显 */
    public record Result(long accountDeleted, long anonymizedRecords,
                         long keptDiagnoses, long keptImages, long keptTrainingAssets,
                         long deletedVerificationCodes) {}

    public Preview preview(Long userId, Long currentAdminId) {
        User u = userRepo.findById(userId).orElse(null);
        if (u == null) return null;

        List<DiagnosisRecord> records = diagnosisRepo.findByUserId(userId);
        List<Long> recordIds = records.stream().map(DiagnosisRecord::getId).toList();
        List<DiseaseImage> images = recordIds.isEmpty()
                ? List.of() : imageRepo.findByDiagnosisIdIn(recordIds);
        List<TrainingDataset> assets = recordIds.isEmpty()
                ? List.of() : trainingRepo.findByDiagnosisIdIn(recordIds);

        List<String> blockers = new ArrayList<>();
        if (currentAdminId != null && currentAdminId.equals(userId)) {
            blockers.add("不能删除当前登录的账号（会导致自己立刻被踢出后台）");
        }
        if (u.getRole() == UserRole.ADMIN && userRepo.countByRole(UserRole.ADMIN) <= 1) {
            blockers.add("系统至少保留一名管理员，无法删除最后一个管理员账号");
        }

        return new Preview(
                u.getId(), u.getNickname(),
                AuthService.maskPhone(u.getPhone() == null ? "" : u.getPhone()),
                u.getCountryCode(), u.getRole() == null ? "" : u.getRole().name(),
                Boolean.TRUE.equals(u.getIsActive()),
                records.size(), images.size(), assets.size(),
                assets.stream().filter(a -> Boolean.TRUE.equals(a.getTrainingReady())).count(),
                verificationRepo.countByPhoneFull(phoneFull(u)),
                blockers);
    }

    /**
     * 删除账号（调用方必须已完成管理员身份与密码二次校验）
     *
     * <p>顺序：先把识别记录与用户解绑（匿名化）→ 清验证码 → 删账号。
     * 生产库上 {@code diagnosis_record.user_id} 有外键指向 user，
     * 所以**必须先解绑再删账号**，否则外键会拦下删除。
     */
    @Transactional
    public Result delete(Long userId) {
        User u = userRepo.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("用户不存在: " + userId));

        // 1) 识别记录：只解除与个人的关联，数据本身原样保留
        List<DiagnosisRecord> records = diagnosisRepo.findByUserId(userId);
        for (DiagnosisRecord r : records) {
            r.setUserId(null);          // 断开关联：数据不再属于任何账号
            r.setDeviceUuid(null);      // 设备标识属于个人信息，且对数据价值无贡献
            r.setDeviceInfo(null);      // 设备型号/系统指纹同理
        }
        if (!records.isEmpty()) {
            diagnosisRepo.saveAll(records);
        }
        List<Long> recordIds = records.stream().map(DiagnosisRecord::getId).toList();

        // 2) 图片与训练数据资产：一个字都不动（平台核心资产）
        long keptImages = recordIds.isEmpty() ? 0 : imageRepo.findByDiagnosisIdIn(recordIds).size();
        long keptAssets = recordIds.isEmpty() ? 0 : trainingRepo.findByDiagnosisIdIn(recordIds).size();

        // 3) 短信验证码记录：纯个人信息残留，随账号删除
        String phoneFull = phoneFull(u);
        long codes = verificationRepo.countByPhoneFull(phoneFull);
        if (codes > 0) {
            verificationRepo.deleteByPhoneFull(phoneFull);
        }

        // 4) 删除账号本身
        userRepo.delete(u);

        log.warn("用户账号已删除（数据资产保留）: id={}, role={}, phone={}***, "
                        + "匿名化识别记录={}, 保留图片={}, 保留训练资产={}, 删除验证码={}",
                userId, u.getRole(), safeHead(u.getPhone()), records.size(), keptImages, keptAssets, codes);

        return new Result(1L, records.size(), records.size(), keptImages, keptAssets, codes);
    }

    private static String phoneFull(User u) {
        return (u.getCountryCode() == null ? "" : u.getCountryCode())
                + (u.getPhone() == null ? "" : u.getPhone());
    }

    private static String safeHead(String phone) {
        if (phone == null || phone.length() < 3) return "***";
        return phone.substring(0, 3);
    }
}
