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
        // Cập nhật lịch (Ví dụ: Khi user bấm tick "Đã uống" trên app)
        [HttpPut("{id}")]
        public async Task<IActionResult> PutMedicationSchedule(int id, MedicationSchedule medicationSchedule)
        {
            if (id != medicationSchedule.Id)
            {
                return BadRequest("ID không trùng khớp.");
            }

            _context.Entry(medicationSchedule).State = EntityState.Modified;

            try
            {
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

            return NoContent(); // Thành công nhưng không cần trả về data (Mã 204)
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

        private bool MedicationScheduleExists(int id)
        {
            return _context.MedicationSchedules.Any(e => e.Id == id);
        }
    }
}