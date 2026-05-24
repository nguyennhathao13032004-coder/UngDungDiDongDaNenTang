using Microsoft.EntityFrameworkCore;
using SaHaBaHealth.Api.Models;

namespace SaHaBaHealth.Api.Data
{
    public class ApplicationDbContext : DbContext
    {
        public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options) : base(options)
        {
        }
        public DbSet<DailyHealthMetric> DailyHealthMetrics { get; set; }
        public DbSet<MedicationSchedule> MedicationSchedules { get; set; }
    }
}