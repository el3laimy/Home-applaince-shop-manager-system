using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ALIkhlasPOS.Domain.Entities;

public enum AuditAction
{
    Create,
    Update,
    Delete
}

public class AuditLog
{
    [Key]
    public Guid Id { get; set; } = Guid.NewGuid();
    
    [Required]
    [MaxLength(100)]
    public string TableName { get; set; } = string.Empty;
    
    [Required]
    public string RecordId { get; set; } = string.Empty;
    
    [Required]
    [Column(TypeName = "varchar(10)")]
    public string Action { get; set; } = string.Empty; // Create, Update, Delete
    
    public string? OldValues { get; set; } // JSON serialized payload
    
    public string? NewValues { get; set; } // JSON serialized payload
    
    [Required]
    [MaxLength(100)]
    public string CreatedBy { get; set; } = "System";
    
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
