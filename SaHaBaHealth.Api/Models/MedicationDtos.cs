namespace SaHaBaHealth.Api.Models
{
    public class DailyMedicationDto
    {
        public int Id { get; set; }
        public string MedicineName { get; set; }
        public string Dosage { get; set; }
        public string TimeToTake { get; set; }
        public bool IsTaken { get; set; } 
    }

    public class ToggleLogRequest
    {
        public int ScheduleId { get; set; }
        public DateTime Date { get; set; }
        public bool IsTaken { get; set; }
    }
}