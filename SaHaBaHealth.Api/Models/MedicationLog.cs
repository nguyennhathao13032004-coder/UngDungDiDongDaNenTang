using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace SaHaBaHealth.Api.Models
{
    [Table("medication_logs")] // Bắt buộc phải có dòng này cho Supabase
    public class MedicationLog
    {
        [Key]
        [Column("id")]
        public int Id { get; set; }

        [Column("schedule_id")]
        public int ScheduleId { get; set; } 

        [Column("log_date")]
        public DateTime LogDate { get; set; } 

        [Column("is_taken")]
        public bool IsTaken { get; set; }

        [Column("created_at")]
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        [ForeignKey("ScheduleId")]
        public MedicationSchedule Schedule { get; set; }
    }
}