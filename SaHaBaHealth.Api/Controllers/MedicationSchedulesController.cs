using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SaHaBaHealth.Api.Data;
using SaHaBaHealth.Api.Models;

namespace SaHaBaHealth.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class MedicationSchedulesController : ControllerBase
    {
        private readonly ApplicationDbContext _context;

        public MedicationSchedulesController(ApplicationDbContext context)
        {
            _context = context;
        }

        // 1. GET: api/MedicationSchedules
        // Lấy danh sách toàn bộ lịch uống thuốc
        [HttpGet]
        public async Task<ActionResult<IEnumerable<MedicationSchedule>>> GetMedicationSchedules()
        {
            return await _context.MedicationSchedules.ToListAsync();
        }

        // Lấy danh sách lịch uống thuốc CỦA RIÊNG MỘT USER
        // GET: api/MedicationSchedules/User/{userId}
        [HttpGet("User/{userId}")]
        public async Task<ActionResult<IEnumerable<MedicationSchedule>>> GetUserSchedules(Guid userId)
        {
            return await _context.MedicationSchedules
                                 .Where(m => m.UserId == userId)
                                 .OrderBy(m => m.TimeToTake) // Sắp xếp theo giờ uống
                                 .ToListAsync();
        }

        // 2. GET: api/MedicationSchedules/5
        // Lấy thông tin chi tiết của 1 lịch uống thuốc theo ID
        [HttpGet("{id}")]
        public async Task<ActionResult<MedicationSchedule>> GetMedicationSchedule(int id)
        {
            var medicationSchedule = await _context.MedicationSchedules.FindAsync(id);

            if (medicationSchedule == null)
            {
                return NotFound("Không tìm thấy lịch uống thuốc này.");
            }

            return medicationSchedule;
        }

        // 3. POST: api/MedicationSchedules
        // Thêm một lịch uống thuốc mới từ App Flutter gửi lên
        [HttpPost]
        public async Task<ActionResult<MedicationSchedule>> PostMedicationSchedule(MedicationSchedule medicationSchedule)
        {
            // Ép thời gian tạo về múi giờ chuẩn UTC cho PostgreSQL
            medicationSchedule.CreatedAt = DateTime.UtcNow;

            _context.MedicationSchedules.Add(medicationSchedule);
            await _context.SaveChangesAsync();

            // Trả về dữ liệu vừa tạo kèm theo mã 201 (Created)
            return CreatedAtAction(nameof(GetMedicationSchedule), new { id = medicationSchedule.Id }, medicationSchedule);
        }

        // 4. PUT: api/MedicationSchedules/5
       [HttpPut("{id}")]
        public async Task<IActionResult> PutMedicationSchedule(int id, MedicationSchedule medicationSchedule)
        {
            if (id != medicationSchedule.Id)
            {
                return BadRequest("ID không trùng khớp.");
            }

            // 1. TÌM LẠI VIÊN THUỐC CŨ TRONG DATABASE
            var existingMed = await _context.MedicationSchedules.FindAsync(id);
            if (existingMed == null)
            {
                return NotFound("Không tìm thấy viên thuốc này.");
            }

            // 2. CHỈ CẬP NHẬT ĐÚNG TRẠNG THÁI UỐNG THUỐC (Bảo toàn UserId và mọi thứ khác)
            existingMed.IsTaken = medicationSchedule.IsTaken;

            try
            {
                // Lưu lại thay đổi
                await _context.SaveChangesAsync();
            }
            catch (DbUpdateConcurrencyException)
            {
                if (!MedicationScheduleExists(id))
                {
                    return NotFound("Không tìm thấy dữ liệu để cập nhật.");
                }
                else
                {
                    throw;
                }
            }

            return NoContent(); 
        }
        
        // 5. DELETE: api/MedicationSchedules/5
        // Xóa một lịch uống thuốc
        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteMedicationSchedule(int id)
        {
            var medicationSchedule = await _context.MedicationSchedules.FindAsync(id);
            if (medicationSchedule == null)
            {
                return NotFound();
            }

            _context.MedicationSchedules.Remove(medicationSchedule);
            await _context.SaveChangesAsync();

            return NoContent();
        }
        // 6. GET: api/MedicationSchedules/User/{userId}/AiReport/{date}
        // API phục vụ cho Bác sĩ AI gom dữ liệu đánh giá
        [HttpGet("User/{userId}/AiReport/{date}")]
        public async Task<ActionResult<DailyHealthReport>> GetAiReport(string userId, string date)
        {
            // 1. Ép chuỗi String thành kiểu DateOnly TRƯỚC KHI gọi Database
            if (!DateOnly.TryParse(date, out DateOnly parsedDate))
            {
                return BadRequest("Định dạng ngày không hợp lệ.");
            }

            // 2. Tìm dữ liệu sức khỏe (KHÔNG dùng ToString() ở đây nữa, so sánh trực tiếp DateOnly)
            var metrics = await _context.DailyHealthMetrics
                .FirstOrDefaultAsync(m => m.UserId == userId && m.Date == parsedDate);

            // ... (Phần code dưới giữ nguyên y hệt lúc nãy) ...
            var report = new DailyHealthReport
            {
                HeartRate = metrics?.HeartRate ?? 0,
                BloodPressure = metrics?.BloodPressure ?? "0/0",
                Weight = metrics?.Weight ?? 0,
                WaterIntakeMl = metrics?.WaterIntakeMl ?? 0,
                TargetWaterMl = metrics?.TargetWaterMl ?? 2000,
                Date = date,
                TakenMedicines = new List<string>(),
                MissedMedicines = new List<string>()
            };

            if (Guid.TryParse(userId, out Guid userGuid))
            {
                var medicines = await _context.MedicationSchedules
                    .Where(m => m.UserId == userGuid)
                    .ToListAsync();

                report.TakenMedicines = medicines.Where(m => m.IsTaken).Select(m => m.MedicineName).ToList();
                report.MissedMedicines = medicines.Where(m => !m.IsTaken).Select(m => m.MedicineName).ToList();
            }

            return Ok(report);
        }
        
        private bool MedicationScheduleExists(int id)
        {
            return _context.MedicationSchedules.Any(e => e.Id == id);
        }

        
    }
}