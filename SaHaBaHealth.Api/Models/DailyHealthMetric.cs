using System.ComponentModel.DataAnnotations;

namespace SaHaBaHealth.Api.Models
{
    public class DailyHealthMetric
    {
        [Key]
        public int Id { get; set; }
        
        [Required]
        public string UserId { get; set; } = string.Empty;
        
        // Lưu theo từng ngày để hôm sau reset lượng nước về 0
        public DateOnly Date { get; set; } 
        
        public int WaterIntakeMl { get; set; } // Lượng nước uống (VD: 800)
        public int TargetWaterMl { get; set; } = 2000; // Mục tiêu (VD: 2000)
        public int HeartRate { get; set; } // Nhịp tim
        public string BloodPressure { get; set; } = string.Empty; // Huyết áp (VD: "120/80")
        public double Weight { get; set; } // Cân nặng
    }
}