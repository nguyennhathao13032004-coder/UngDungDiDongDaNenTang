using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SaHaBaHealth.Api.Data;
using SaHaBaHealth.Api.Models;

namespace SaHaBaHealth.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class DailyHealthMetricsController : ControllerBase
    {
        private readonly ApplicationDbContext _context;

        public DailyHealthMetricsController(ApplicationDbContext context)
        {
            _context = context;
        }

        // 1. API lấy dữ liệu sức khỏe của ngày hôm nay
        [HttpGet("User/{userId}/Today")]
        public async Task<ActionResult<DailyHealthMetric>> GetTodayMetric(string userId)
        {
            // Lấy ngày hiện tại theo múi giờ Việt Nam (UTC+7)
            var today = DateOnly.FromDateTime(DateTime.UtcNow.AddHours(7)); 

            var metric = await _context.DailyHealthMetrics
                .FirstOrDefaultAsync(m => m.UserId == userId && m.Date == today);

            // Nếu chưa có dữ liệu của ngày hôm nay, trả về một bản nháp mặc định
            if (metric == null)
            {
                return new DailyHealthMetric
                {
                    UserId = userId,
                    Date = today,
                    WaterIntakeMl = 0,
                    TargetWaterMl = 2000,
                    HeartRate = 0,
                    BloodPressure = "0/0",
                    Weight = 0
                };
            }

            return metric;
        }

        // 2. API Cập nhật (hoặc Tạo mới) dữ liệu sức khỏe
        [HttpPost("Upsert")]
        public async Task<IActionResult> UpsertMetric([FromBody] DailyHealthMetric metric)
        {
            var existingMetric = await _context.DailyHealthMetrics
                .FirstOrDefaultAsync(m => m.UserId == metric.UserId && m.Date == metric.Date);

            if (existingMetric != null)
            {
                // Nếu đã có -> Cập nhật thông số
                existingMetric.WaterIntakeMl = metric.WaterIntakeMl;
                existingMetric.TargetWaterMl = metric.TargetWaterMl;
                existingMetric.HeartRate = metric.HeartRate;
                existingMetric.BloodPressure = metric.BloodPressure;
                existingMetric.Weight = metric.Weight;
            }
            else
            {
                // Nếu chưa có -> Tạo mới dòng dữ liệu
                _context.DailyHealthMetrics.Add(metric);
            }

            await _context.SaveChangesAsync();
            return Ok(metric);
        }
        // API phục vụ cho Bác sĩ AI
        [HttpGet("User/{userId}/AiReport/{date}")]
        public async Task<ActionResult<DailyHealthReport>> GetAiReport(Guid userId, string date)
        {
            // 1. Lấy dữ liệu sức khỏe (cần gọi sang bảng DailyHealthMetrics)
            // Lưu ý: Nếu UserId bên bảng DailyHealthMetrics là string, bạn cần ép kiểu ToString()
            var metrics = await _context.DailyHealthMetrics
                .FirstOrDefaultAsync(m => m.UserId == userId.ToString() && m.Date.ToString() == date);

            // Nếu chưa có dữ liệu sức khỏe, ta vẫn trả về report với thông số 0 để AI không bị lỗi
            var report = new DailyHealthReport
            {
                HeartRate = metrics?.HeartRate ?? 0,
                BloodPressure = metrics?.BloodPressure ?? "0/0",
                Weight = metrics?.Weight ?? 0,
                WaterIntakeMl = metrics?.WaterIntakeMl ?? 0,
                TargetWaterMl = metrics?.TargetWaterMl ?? 2000,
                Date = date, // Dùng ngày từ URL
                TakenMedicines = new List<string>(),
                MissedMedicines = new List<string>()
            };

            // 2. Lấy dữ liệu thuốc
            var medicines = await _context.MedicationSchedules
                .Where(m => m.UserId == userId)
                .ToListAsync();

            // 3. Phân loại thuốc
            // Giả sử cột 'IsTaken' là bool
            report.TakenMedicines = medicines.Where(m => m.IsTaken).Select(m => m.MedicineName).ToList();
            report.MissedMedicines = medicines.Where(m => !m.IsTaken).Select(m => m.MedicineName).ToList();

            return Ok(report);
        }
    }
}