# مشروع ALIkhlasPOS (نظام الكاشير والإدارة)

## نظرة عامة (Overview)
نظام متكامل لإدارة نقاط البيع (POS) وتخطيط موارد المؤسسات (ERP) مصمم للمراكز التجارية، وتحديداً محلات الأدوات المنزلية وتجهيزات العرائس. يركز النظام على السرعة، إدارة المخزون، ودعم المبيعات المعقدة مثل الأقساط (Installments) والمجموعات (Bundles).

## المكدس التقني (Tech Stack)
- **الواجهة الأمامية (Frontend):** Flutter for Desktop (Windows/Linux) - لضمان تجربة مستخدم عصرية وسريعة.
- **الواجهة الخلفية (Backend):** C# .NET 9 Web API - مبنية باستخدام Clean Architecture و CQRS pattern.
- **قواعد البيانات (Databases):** 
  - PostgreSQL (القاعدة الأساسية).
  - Redis (للتخزين المؤقت Caching للباركود والأسعار والـ Sessions).

## الهندسة المعمارية (Architecture)
### Backend (.NET Core)
مقسم إلى عدة طبقات (Layers) لضمان الفصل النظيف (Separation of Concerns):
- **API Layer:** مسؤولة عن استقبال الطلبات (Controllers) مثل `SuppliersController` والمصادقة.
- **Application Layer:** تحتوي على الـ Use Cases، الـ DTOs، والـ Interfaces (مثل `IUnitOfWork` و `IRepository`).
- **Domain Layer:** تحتوي على الكيانات الأساسية (Entities) مثل `Invoice`, `ProductUnit`, `Supplier`، وقواعد العمل (Business Rules).
- **Infrastructure Layer:** مسؤولة عن الاتصال بقاعدة البيانات (Entity Framework Core)، الـ Migrations، وعمليات الـ Redis.

### Frontend (Flutter)
- تصميم يعتمد على الـ Widgets القابلة لإعادة الاستخدام.
- إدارة الحالة (State Management) باستخدام Provider/Riverpod أو Bloc (حسب المطبق).
- هيكلة المجلدات تتضمن `core` للأساسيات المشتركة (مثل `main_shell.dart`)، و `features` لكل وحدة وظيفية (POS, Inventory, Customers، الخ).

## الميزات والوحدات الأساسية (Core Features)
1. **محرك الباركود الذكي:** دعم EAN-13 و Code 128، مع توليد باركود تلقائي للأصناف غير المعلمة.
2. **إدارة المخازن (Inventory):** دعم الأصناف المركبة (Bundles) وتعدد الوحدات (قطعة، دستة، كرتونة) للمنتج الواحد.
3. **نظام العرائس والأقساط:** حجز بضائع، جدولة أقساط، وإصدار كشوفات حساب مفصلة للمتبقيات والدفعات.
4. **الموردين والمصروفات (Suppliers & Expenses):** تتبع حسابات الموردين، وإدارة المصروفات اليومية للمحل.
5. **المزامنة مع الخزينة (Treasury Sync):** تسجيل المبيعات النقدية والمقدمات بشكل تلقائي في الخزينة.

## تعليمات برمجية (Coding Conventions)
- **Backend:** استخدام C# الحديثة، حقن التبعيات (Dependency Injection)، معالجة الأخطاء الشاملة (Global Exception Handling)، واستخدام الـ Async/Await بشكل كامل.
- **Frontend:** الحفاظ على اللغات (Localization) باللغة العربية، استخدام Material Design، وفصل منطق واجهة المستخدم عن منطق الأعمال (UI/Business Logic Separation).
- جميع الرسائل، التنبيهات، والتوثيقات يجب أن تكون بـ **اللغة العربية** لسهولة التواصل مع المستخدم النهائي.
