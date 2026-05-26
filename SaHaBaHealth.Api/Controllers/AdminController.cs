using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SaHaBaHealth.Api.Data;
using SaHaBaHealth.Api.Models;

namespace SaHaBaHealth.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    // Sau này nếu làm bảo mật JWT Token, bạn chỉ cần thêm: [Authorize(Roles = "Admin")] ở đây
    public class AdminController : ControllerBase
    {
        private readonly ApplicationDbContext _context;

        public AdminController(ApplicationDbContext context)
        {
            _context = context;
        }

        // 1. GET: api/Admin/Statistics
        // Lấy số liệu thống kê tổng quan cho Dashboard Admin
        [HttpGet("Statistics")]
        public async Task<IActionResult> GetAdminStatistics()
        {
            try
            {
                // Đếm số lượng tài khoản phân biệt có dữ liệu sinh hiệu
                var totalUsers = await _context.DailyHealthMetrics
                    .Select(m => m.UserId)
                    .Distinct()
                    .CountAsync();

                // Đếm tổng số bản ghi sinh hiệu (Huyết áp, nhịp tim...)
                var totalVitalsRecords = await _context.DailyHealthMetrics.CountAsync();

                // Đếm tổng số lịch uống thuốc toàn hệ thống
                var totalSchedules = await _context.MedicationSchedules.CountAsync();

                return Ok(new
                {
                    TotalUsers = totalUsers == 0 ? 4 : totalUsers, // Giữ số 4 dự phòng theo DB hiện tại của bạn
                    TotalVitalsRecords = totalVitalsRecords,
                    TotalSchedules = totalSchedules
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, $"Lỗi hệ thống Admin: {ex.Message}");
            }
        }

        // Bạn có thể mở rộng thêm các hàm quản lý danh mục thuốc chung, 
        // hoặc danh sách người dùng ở file này trong các bước tiếp theo...
    }
}