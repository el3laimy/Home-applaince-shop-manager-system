using System.Net;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc;

namespace ALIkhlasPOS.API.Middleware;

public class GlobalExceptionMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<GlobalExceptionMiddleware> _logger;
    private readonly IHostEnvironment _env;

    public GlobalExceptionMiddleware(RequestDelegate next, ILogger<GlobalExceptionMiddleware> logger, IHostEnvironment env)
    {
        _next = next;
        _logger = logger;
        _env = env;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "An unhandled exception has occurred.");
            await HandleExceptionAsync(context, ex);
        }
    }

    private async Task HandleExceptionAsync(HttpContext context, Exception ex)
    {
        context.Response.ContentType = "application/problem+json";
        
        var statusCode = (int)HttpStatusCode.InternalServerError;
        var message = "حدث خطأ غير متوقع. يرجى الاتصال بالدعم الفني.";
        var title = "خطأ في النظام";

        if (ex is Microsoft.EntityFrameworkCore.DbUpdateException dbEx)
        {
            statusCode = (int)HttpStatusCode.BadRequest;
            title = "تعارض في البيانات";
            
            var innerMsg = dbEx.InnerException?.Message ?? string.Empty;
            if (innerMsg.Contains("duplicate key", StringComparison.OrdinalIgnoreCase))
            {
                message = "هذا السجل (أو الباركود/الكود) موجود بالفعل، ولا يمكن تكراره.";
            }
            else if (innerMsg.Contains("foreign key", StringComparison.OrdinalIgnoreCase) || innerMsg.Contains("violates foreign key", StringComparison.OrdinalIgnoreCase))
            {
                message = "لا يمكن تنفيذ العملية (كالحذف أو التعديل) لارتباط هذا السجل ببيانات أو فواتير أخرى مسجلة مسبقاً.";
            }
            else
            {
                message = "تعذر حفظ البيانات بسبب تعارض مع القيود النظامية لقاعدة البيانات.";
            }
        }
        else if (ex is InvalidOperationException invEx)
        {
            statusCode = (int)HttpStatusCode.BadRequest;
            title = "عملية غير مسموحة";
            message = invEx.Message; // e.g. from AccountingService
        }

        context.Response.StatusCode = statusCode;

        var problemDetails = new ProblemDetails
        {
            Status = statusCode,
            Title = title,
            Detail = _env.IsDevelopment() ? ex.Message : message,
            Instance = context.Request.Path
        };

        if (_env.IsDevelopment())
        {
            problemDetails.Extensions["traceId"] = context.TraceIdentifier;
            problemDetails.Extensions["stackTrace"] = ex.StackTrace;
        }

        var json = JsonSerializer.Serialize(problemDetails, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        });

        await context.Response.WriteAsync(json);
    }
}
