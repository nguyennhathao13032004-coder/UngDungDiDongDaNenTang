using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace SaHaBaHealth.Api.Models
{
    [Table("medication_schedules")] 
    public class MedicationSchedule
    {
        [Key]
        [Column("id")]
        public int Id { get; set; }

        [Column("user_id")]
        public Guid UserId { get; set; } 

        [Required]
        [Column("medicine_name")]
        public string MedicineName { get; set; } = string.Empty;

        [Column("dosage")]
        public string Dosage { get; set; } = string.Empty; 

        [Column("time_to_take")]
        public TimeSpan TimeToTake { get; set; } 

        [Column("is_taken")]
        public bool IsTaken { get; set; } = false;

        [Column("created_at")]
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}