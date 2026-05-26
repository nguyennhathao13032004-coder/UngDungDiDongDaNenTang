namespace SaHaBaHealth.Api.Models
{
    public class DailyHealthReport
    {
        // Thông tin sức khỏe
        public int HeartRate { get; set; }
        public string BloodPressure { get; set; } = string.Empty;
        public double Weight { get; set; }
        public int WaterIntakeMl { get; set; }
        public int TargetWaterMl { get; set; }
        public string Date { get; set; } = string.Empty;

        // Thông tin thuốc (được gom từ bảng MedicationSchedules)
        public List<string> TakenMedicines { get; set; } = new List<string>();
        public List<string> MissedMedicines { get; set; } = new List<string>();
    }
}