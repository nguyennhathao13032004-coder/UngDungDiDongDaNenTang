namespace SaHaBaHealth.Api.Models
{
    public class DailyHealthReportForAiDto
    {
        public string Date { get; set; }
        // Chỉ số sinh hiệu
        public int HeartRate { get; set; }
        public string BloodPressure { get; set; }
        public double Weight { get; set; }
        // Lượng nước
        public int WaterIntakeMl { get; set; }
        public int TargetWaterMl { get; set; }
        // Tình trạng thuốc
        public List<string> TakenMedicines { get; set; } = new List<string>();
        public List<string> MissedMedicines { get; set; } = new List<string>();
    }
}