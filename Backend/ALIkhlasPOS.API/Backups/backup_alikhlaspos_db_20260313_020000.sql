--
-- PostgreSQL database dump
--

\restrict YqcgOEoNToEZgwnOr2OnYcZifoDbeIHIXANlLQiTHbII9sKBFr9iqsczGRH6FWS

-- Dumped from database version 15.16
-- Dumped by pg_dump version 15.16

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

ALTER TABLE ONLY public."Suppliers" DROP CONSTRAINT "FK_Suppliers_Accounts_AccountId";
ALTER TABLE ONLY public."StockMovements" DROP CONSTRAINT "FK_StockMovements_Products_ProductId";
ALTER TABLE ONLY public."StockAdjustments" DROP CONSTRAINT "FK_StockAdjustments_Products_ProductId";
ALTER TABLE ONLY public."Shifts" DROP CONSTRAINT "FK_Shifts_Users_CashierId";
ALTER TABLE ONLY public."ReturnInvoices" DROP CONSTRAINT "FK_ReturnInvoices_Invoices_OriginalInvoiceId";
ALTER TABLE ONLY public."ReturnInvoiceItems" DROP CONSTRAINT "FK_ReturnInvoiceItems_ReturnInvoices_ReturnInvoiceId";
ALTER TABLE ONLY public."ReturnInvoiceItems" DROP CONSTRAINT "FK_ReturnInvoiceItems_Products_ProductId";
ALTER TABLE ONLY public."RefreshTokens" DROP CONSTRAINT "FK_RefreshTokens_Users_UserId";
ALTER TABLE ONLY public."PurchaseInvoices" DROP CONSTRAINT "FK_PurchaseInvoices_Suppliers_SupplierId";
ALTER TABLE ONLY public."PurchaseInvoices" DROP CONSTRAINT "FK_PurchaseInvoices_JournalEntries_JournalEntryId";
ALTER TABLE ONLY public."PurchaseInvoiceItems" DROP CONSTRAINT "FK_PurchaseInvoiceItems_PurchaseInvoices_PurchaseInvoiceId";
ALTER TABLE ONLY public."PurchaseInvoiceItems" DROP CONSTRAINT "FK_PurchaseInvoiceItems_Products_ProductId";
ALTER TABLE ONLY public."ProductUnits" DROP CONSTRAINT "FK_ProductUnits_Products_ProductId";
ALTER TABLE ONLY public."JournalEntryLines" DROP CONSTRAINT "FK_JournalEntryLines_JournalEntries_JournalEntryId";
ALTER TABLE ONLY public."JournalEntryLines" DROP CONSTRAINT "FK_JournalEntryLines_Accounts_AccountId";
ALTER TABLE ONLY public."Invoices" DROP CONSTRAINT "FK_Invoices_Customers_CustomerId";
ALTER TABLE ONLY public."InvoiceItems" DROP CONSTRAINT "FK_InvoiceItems_Products_ProductId";
ALTER TABLE ONLY public."InvoiceItems" DROP CONSTRAINT "FK_InvoiceItems_Invoices_InvoiceId";
ALTER TABLE ONLY public."Installments" DROP CONSTRAINT "FK_Installments_Invoices_InvoiceId";
ALTER TABLE ONLY public."Expenses" DROP CONSTRAINT "FK_Expenses_JournalEntries_JournalEntryId";
ALTER TABLE ONLY public."Expenses" DROP CONSTRAINT "FK_Expenses_ExpenseCategories_CategoryId";
ALTER TABLE ONLY public."CashTransactions" DROP CONSTRAINT "FK_CashTransactions_JournalEntries_JournalEntryId";
ALTER TABLE ONLY public."CashTransactions" DROP CONSTRAINT "FK_CashTransactions_Accounts_TargetAccountId";
ALTER TABLE ONLY public."Bundles" DROP CONSTRAINT "FK_Bundles_Products_SubProductId";
ALTER TABLE ONLY public."Bundles" DROP CONSTRAINT "FK_Bundles_Products_ParentProductId";
ALTER TABLE ONLY public."Accounts" DROP CONSTRAINT "FK_Accounts_Accounts_ParentAccountId";
DROP INDEX public."IX_Suppliers_AccountId";
DROP INDEX public."IX_StockMovements_ProductId";
DROP INDEX public."IX_StockAdjustments_ProductId";
DROP INDEX public."IX_Shifts_CashierId";
DROP INDEX public."IX_ReturnInvoices_OriginalInvoiceId";
DROP INDEX public."IX_ReturnInvoiceItems_ReturnInvoiceId";
DROP INDEX public."IX_ReturnInvoiceItems_ProductId";
DROP INDEX public."IX_RefreshTokens_UserId";
DROP INDEX public."IX_PurchaseInvoices_SupplierId";
DROP INDEX public."IX_PurchaseInvoices_JournalEntryId";
DROP INDEX public."IX_PurchaseInvoiceItems_PurchaseInvoiceId";
DROP INDEX public."IX_PurchaseInvoiceItems_ProductId";
DROP INDEX public."IX_Products_GlobalBarcode";
DROP INDEX public."IX_ProductUnits_ProductId";
DROP INDEX public."IX_JournalEntryLines_JournalEntryId";
DROP INDEX public."IX_JournalEntryLines_AccountId";
DROP INDEX public."IX_Invoices_CustomerId";
DROP INDEX public."IX_InvoiceItems_ProductId";
DROP INDEX public."IX_InvoiceItems_InvoiceId";
DROP INDEX public."IX_Installments_InvoiceId";
DROP INDEX public."IX_Expenses_JournalEntryId";
DROP INDEX public."IX_Expenses_CategoryId";
DROP INDEX public."IX_CashTransactions_TargetAccountId";
DROP INDEX public."IX_CashTransactions_JournalEntryId";
DROP INDEX public."IX_Bundles_SubProductId";
DROP INDEX public."IX_Bundles_ParentProductId";
DROP INDEX public."IX_Accounts_ParentAccountId";
ALTER TABLE ONLY public."__EFMigrationsHistory" DROP CONSTRAINT "PK___EFMigrationsHistory";
ALTER TABLE ONLY public."Users" DROP CONSTRAINT "PK_Users";
ALTER TABLE ONLY public."Suppliers" DROP CONSTRAINT "PK_Suppliers";
ALTER TABLE ONLY public."StockMovements" DROP CONSTRAINT "PK_StockMovements";
ALTER TABLE ONLY public."StockAdjustments" DROP CONSTRAINT "PK_StockAdjustments";
ALTER TABLE ONLY public."ShopSettings" DROP CONSTRAINT "PK_ShopSettings";
ALTER TABLE ONLY public."Shifts" DROP CONSTRAINT "PK_Shifts";
ALTER TABLE ONLY public."ReturnInvoices" DROP CONSTRAINT "PK_ReturnInvoices";
ALTER TABLE ONLY public."ReturnInvoiceItems" DROP CONSTRAINT "PK_ReturnInvoiceItems";
ALTER TABLE ONLY public."RefreshTokens" DROP CONSTRAINT "PK_RefreshTokens";
ALTER TABLE ONLY public."PurchaseInvoices" DROP CONSTRAINT "PK_PurchaseInvoices";
ALTER TABLE ONLY public."PurchaseInvoiceItems" DROP CONSTRAINT "PK_PurchaseInvoiceItems";
ALTER TABLE ONLY public."Products" DROP CONSTRAINT "PK_Products";
ALTER TABLE ONLY public."ProductUnits" DROP CONSTRAINT "PK_ProductUnits";
ALTER TABLE ONLY public."JournalEntryLines" DROP CONSTRAINT "PK_JournalEntryLines";
ALTER TABLE ONLY public."JournalEntries" DROP CONSTRAINT "PK_JournalEntries";
ALTER TABLE ONLY public."Invoices" DROP CONSTRAINT "PK_Invoices";
ALTER TABLE ONLY public."InvoiceItems" DROP CONSTRAINT "PK_InvoiceItems";
ALTER TABLE ONLY public."Installments" DROP CONSTRAINT "PK_Installments";
ALTER TABLE ONLY public."Expenses" DROP CONSTRAINT "PK_Expenses";
ALTER TABLE ONLY public."ExpenseCategories" DROP CONSTRAINT "PK_ExpenseCategories";
ALTER TABLE ONLY public."Customers" DROP CONSTRAINT "PK_Customers";
ALTER TABLE ONLY public."CashTransactions" DROP CONSTRAINT "PK_CashTransactions";
ALTER TABLE ONLY public."Bundles" DROP CONSTRAINT "PK_Bundles";
ALTER TABLE ONLY public."AuditLogs" DROP CONSTRAINT "PK_AuditLogs";
ALTER TABLE ONLY public."Accounts" DROP CONSTRAINT "PK_Accounts";
DROP TABLE public."__EFMigrationsHistory";
DROP TABLE public."Users";
DROP TABLE public."Suppliers";
DROP TABLE public."StockMovements";
DROP TABLE public."StockAdjustments";
DROP TABLE public."ShopSettings";
DROP TABLE public."Shifts";
DROP TABLE public."ReturnInvoices";
DROP TABLE public."ReturnInvoiceItems";
DROP TABLE public."RefreshTokens";
DROP TABLE public."PurchaseInvoices";
DROP TABLE public."PurchaseInvoiceItems";
DROP TABLE public."Products";
DROP TABLE public."ProductUnits";
DROP TABLE public."JournalEntryLines";
DROP TABLE public."JournalEntries";
DROP TABLE public."Invoices";
DROP TABLE public."InvoiceItems";
DROP TABLE public."Installments";
DROP TABLE public."Expenses";
DROP TABLE public."ExpenseCategories";
DROP TABLE public."Customers";
DROP TABLE public."CashTransactions";
DROP TABLE public."Bundles";
DROP TABLE public."AuditLogs";
DROP TABLE public."Accounts";
SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: Accounts; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public."Accounts" (
    "Id" uuid NOT NULL,
    "Code" character varying(50) NOT NULL,
    "Name" character varying(100) NOT NULL,
    "Type" integer NOT NULL,
    "IsActive" boolean NOT NULL,
    "ParentAccountId" uuid
);


ALTER TABLE public."Accounts" OWNER TO admin;

--
-- Name: AuditLogs; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public."AuditLogs" (
    "Id" uuid NOT NULL,
    "TableName" character varying(100) NOT NULL,
    "RecordId" text NOT NULL,
    "Action" character varying(10) NOT NULL,
    "OldValues" text,
    "NewValues" text,
    "CreatedBy" character varying(100) NOT NULL,
    "CreatedAt" timestamp with time zone NOT NULL
);


ALTER TABLE public."AuditLogs" OWNER TO admin;

--
-- Name: Bundles; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public."Bundles" (
    "Id" uuid NOT NULL,
    "Name" text NOT NULL,
    "ParentProductId" uuid NOT NULL,
    "SubProductId" uuid NOT NULL,
    "QuantityRequired" integer NOT NULL,
    "DiscountAmount" numeric(18,2) NOT NULL,
    "CreatedAt" timestamp with time zone NOT NULL
);


ALTER TABLE public."Bundles" OWNER TO admin;

--
-- Name: CashTransactions; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public."CashTransactions" (
    "Id" uuid NOT NULL,
    "Date" timestamp with time zone NOT NULL,
    "ReceiptNumber" character varying(50),
    "Type" integer NOT NULL,
    "Amount" numeric(18,2) NOT NULL,
    "Description" character varying(500),
    "TargetAccountId" uuid,
    "JournalEntryId" uuid,
    "CreatedBy" text NOT NULL
);


ALTER TABLE public."CashTransactions" OWNER TO admin;

--
-- Name: Customers; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public."Customers" (
    "Id" uuid NOT NULL,
    "Name" text NOT NULL,
    "Phone" text,
    "Address" text,
    "Notes" text,
    "TotalPurchases" numeric(18,2) NOT NULL,
    "TotalPaid" numeric(18,2) NOT NULL,
    "CreatedAt" timestamp with time zone NOT NULL,
    "IsActive" boolean DEFAULT false NOT NULL
);


ALTER TABLE public."Customers" OWNER TO admin;

--
-- Name: ExpenseCategories; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public."ExpenseCategories" (
    "Id" uuid NOT NULL,
    "Name" character varying(100) NOT NULL,
    "IsActive" boolean NOT NULL
);


ALTER TABLE public."ExpenseCategories" OWNER TO admin;

--
-- Name: Expenses; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public."Expenses" (
    "Id" uuid NOT NULL,
    "Date" timestamp with time zone NOT NULL,
    "Amount" numeric(18,2) NOT NULL,
    "Description" character varying(500),
    "JournalEntryId" uuid,
    "CreatedBy" text NOT NULL,
    "CategoryId" uuid DEFAULT '44444444-4444-4444-4444-444444444444'::uuid NOT NULL,
    "ReceiptImagePath" text
);


ALTER TABLE public."Expenses" OWNER TO admin;

--
-- Name: Installments; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public."Installments" (
    "Id" uuid NOT NULL,
    "InvoiceId" uuid NOT NULL,
    "CustomerId" uuid NOT NULL,
    "Amount" numeric(18,2) NOT NULL,
    "DueDate" timestamp with time zone NOT NULL,
    "Status" integer NOT NULL,
    "ReminderSent" boolean NOT NULL,
    "CreatedAt" timestamp with time zone NOT NULL,
    "PaidAt" timestamp with time zone
);


ALTER TABLE public."Installments" OWNER TO admin;

--
-- Name: InvoiceItems; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public."InvoiceItems" (
    "Id" uuid NOT NULL,
    "InvoiceId" uuid NOT NULL,
    "ProductId" uuid NOT NULL,
    "Quantity" integer NOT NULL,
    "UnitPrice" numeric(18,2) NOT NULL
);


ALTER TABLE public."InvoiceItems" OWNER TO admin;

--
-- Name: Invoices; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public."Invoices" (
    "Id" uuid NOT NULL,
    "InvoiceNo" text NOT NULL,
    "CustomerId" uuid,
    "TotalAmount" numeric(18,2) NOT NULL,
    "DiscountAmount" numeric(18,2) NOT NULL,
    "PaymentType" integer NOT NULL,
    "Status" integer NOT NULL,
    "Notes" text,
    "CreatedAt" timestamp with time zone NOT NULL,
    "CreatedBy" text NOT NULL,
    "CashierId" uuid,
    "PaidAmount" numeric(18,2) DEFAULT 0.0 NOT NULL,
    "RemainingAmount" numeric(18,2) DEFAULT 0.0 NOT NULL,
    "SubTotal" numeric(18,2) DEFAULT 0.0 NOT NULL,
    "VatAmount" numeric(18,2) DEFAULT 0.0 NOT NULL,
    "VatRate" numeric(5,2) DEFAULT 0.0 NOT NULL,
    "PaymentReference" text,
    "EventDate" timestamp with time zone,
    "DeliveryDate" timestamp with time zone,
    "IsBridal" boolean DEFAULT false NOT NULL,
    "BridalNotes" text,
    "InstallmentCount" integer DEFAULT 0 NOT NULL,
    "InstallmentPeriod" integer DEFAULT 0 NOT NULL,
    "InterestRate" numeric DEFAULT 0.0 NOT NULL
);


ALTER TABLE public."Invoices" OWNER TO admin;

--
-- Name: JournalEntries; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public."JournalEntries" (
    "Id" uuid NOT NULL,
    "VoucherNumber" character varying(50),
    "Date" timestamp with time zone NOT NULL,
    "Reference" character varying(500),
    "Description" character varying(500),
    "CreatedBy" text NOT NULL,
    "IsClosed" boolean DEFAULT false NOT NULL
);


ALTER TABLE public."JournalEntries" OWNER TO admin;

--
-- Name: JournalEntryLines; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public."JournalEntryLines" (
    "Id" uuid NOT NULL,
    "JournalEntryId" uuid NOT NULL,
    "AccountId" uuid NOT NULL,
    "Description" character varying(500),
    "Debit" numeric(18,2) NOT NULL,
    "Credit" numeric(18,2) NOT NULL
);


ALTER TABLE public."JournalEntryLines" OWNER TO admin;

--
-- Name: ProductUnits; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public."ProductUnits" (
    "Id" uuid NOT NULL,
    "ProductId" uuid NOT NULL,
    "UnitType" integer NOT NULL,
    "ConversionFactor" integer NOT NULL,
    "UnitPrice" numeric(18,2) NOT NULL,
    "UnitBarcode" text
);


ALTER TABLE public."ProductUnits" OWNER TO admin;

--
-- Name: Products; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public."Products" (
    "Id" uuid NOT NULL,
    "Name" text NOT NULL,
    "GlobalBarcode" text,
    "InternalBarcode" text,
    "Description" text,
    "PurchasePrice" numeric(18,2) NOT NULL,
    "WholesalePrice" numeric(18,2) NOT NULL,
    "Price" numeric(18,2) NOT NULL,
    "StockQuantity" numeric NOT NULL,
    "MinStockAlert" numeric NOT NULL,
    "ExpiryDate" timestamp with time zone,
    "Category" character varying(100),
    "CreatedAt" timestamp with time zone NOT NULL,
    "UpdatedAt" timestamp with time zone,
    "ImageUrl" text,
    "IsActive" boolean DEFAULT false NOT NULL
);


ALTER TABLE public."Products" OWNER TO admin;

--
-- Name: PurchaseInvoiceItems; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public."PurchaseInvoiceItems" (
    "Id" uuid NOT NULL,
    "PurchaseInvoiceId" uuid NOT NULL,
    "ProductId" uuid NOT NULL,
    "Quantity" numeric NOT NULL,
    "UnitPrice" numeric(18,2) NOT NULL,
    "TotalPrice" numeric(18,2) NOT NULL
);


ALTER TABLE public."PurchaseInvoiceItems" OWNER TO admin;

--
-- Name: PurchaseInvoices; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public."PurchaseInvoices" (
    "Id" uuid NOT NULL,
    "InvoiceNo" character varying(50),
    "Date" timestamp with time zone NOT NULL,
    "SupplierId" uuid NOT NULL,
    "TotalAmount" numeric(18,2) NOT NULL,
    "Discount" numeric(18,2) NOT NULL,
    "NetAmount" numeric(18,2) NOT NULL,
    "PaidAmount" numeric(18,2) NOT NULL,
    "RemainingAmount" numeric(18,2) NOT NULL,
    "JournalEntryId" uuid,
    "CreatedBy" text NOT NULL,
    "CreatedAt" timestamp with time zone DEFAULT '-infinity'::timestamp with time zone NOT NULL,
    "Notes" text,
    "Status" integer DEFAULT 0 NOT NULL
);


ALTER TABLE public."PurchaseInvoices" OWNER TO admin;

--
-- Name: RefreshTokens; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public."RefreshTokens" (
    "Id" uuid NOT NULL,
    "Token" text NOT NULL,
    "Expires" timestamp with time zone NOT NULL,
    "Created" timestamp with time zone NOT NULL,
    "Revoked" timestamp with time zone,
    "UserId" uuid NOT NULL
);


ALTER TABLE public."RefreshTokens" OWNER TO admin;

--
-- Name: ReturnInvoiceItems; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public."ReturnInvoiceItems" (
    "Id" uuid NOT NULL,
    "ReturnInvoiceId" uuid NOT NULL,
    "ProductId" uuid NOT NULL,
    "Quantity" numeric NOT NULL,
    "UnitPrice" numeric(18,2) NOT NULL
);


ALTER TABLE public."ReturnInvoiceItems" OWNER TO admin;

--
-- Name: ReturnInvoices; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public."ReturnInvoices" (
    "Id" uuid NOT NULL,
    "ReturnNo" text NOT NULL,
    "OriginalInvoiceId" uuid NOT NULL,
    "Reason" integer NOT NULL,
    "Notes" text,
    "RefundAmount" numeric(18,2) NOT NULL,
    "CreatedAt" timestamp with time zone NOT NULL,
    "CreatedBy" text NOT NULL
);


ALTER TABLE public."ReturnInvoices" OWNER TO admin;

--
-- Name: Shifts; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public."Shifts" (
    "Id" uuid NOT NULL,
    "CashierId" uuid NOT NULL,
    "StartTime" timestamp with time zone NOT NULL,
    "EndTime" timestamp with time zone,
    "OpeningCash" numeric NOT NULL,
    "TotalSales" numeric NOT NULL,
    "TotalCashIn" numeric NOT NULL,
    "TotalCashOut" numeric NOT NULL,
    "ExpectedCash" numeric NOT NULL,
    "ActualCash" numeric NOT NULL,
    "Difference" numeric NOT NULL,
    "Status" integer NOT NULL,
    "Notes" text
);


ALTER TABLE public."Shifts" OWNER TO admin;

--
-- Name: ShopSettings; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public."ShopSettings" (
    "Id" uuid NOT NULL,
    "ShopName" character varying(200) NOT NULL,
    "Address" character varying(500),
    "Phone" character varying(20),
    "Phone2" character varying(20),
    "CommercialRegNo" character varying(50),
    "TaxNumber" character varying(50),
    "LogoBase64" text,
    "ReceiptFooter" character varying(500),
    "VatEnabled" boolean NOT NULL,
    "DefaultVatRate" numeric(5,2) NOT NULL,
    "CurrencySymbol" character varying(10) NOT NULL,
    "CurrencyCode" character varying(10) NOT NULL,
    "UpdatedAt" timestamp with time zone NOT NULL,
    "SmsApiKey" character varying(500),
    "SmsSenderId" character varying(100),
    "SmsProvider" character varying(50),
    "BackupPath" character varying(500)
);


ALTER TABLE public."ShopSettings" OWNER TO admin;

--
-- Name: StockAdjustments; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public."StockAdjustments" (
    "Id" uuid NOT NULL,
    "ProductId" uuid NOT NULL,
    "Type" integer NOT NULL,
    "QuantityAdjusted" integer NOT NULL,
    "Cost" numeric NOT NULL,
    "Reason" character varying(500) NOT NULL,
    "CreatedAt" timestamp with time zone NOT NULL,
    "CreatedBy" character varying(100) NOT NULL
);


ALTER TABLE public."StockAdjustments" OWNER TO admin;

--
-- Name: StockMovements; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public."StockMovements" (
    "Id" uuid NOT NULL,
    "ProductId" uuid NOT NULL,
    "Type" integer NOT NULL,
    "Quantity" integer NOT NULL,
    "BalanceAfter" integer NOT NULL,
    "ReferenceId" uuid,
    "ReferenceNumber" text,
    "Notes" text,
    "CreatedAt" timestamp with time zone NOT NULL,
    "CreatedBy" text NOT NULL
);


ALTER TABLE public."StockMovements" OWNER TO admin;

--
-- Name: Suppliers; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public."Suppliers" (
    "Id" uuid NOT NULL,
    "Name" character varying(100) NOT NULL,
    "Phone" character varying(20),
    "Address" character varying(200),
    "CompanyName" character varying(50),
    "Type" integer NOT NULL,
    "OpeningBalance" numeric(18,2) NOT NULL,
    "AccountId" uuid,
    "CreatedAt" timestamp with time zone DEFAULT '-infinity'::timestamp with time zone NOT NULL
);


ALTER TABLE public."Suppliers" OWNER TO admin;

--
-- Name: Users; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public."Users" (
    "Id" uuid NOT NULL,
    "Username" text NOT NULL,
    "PasswordHash" text NOT NULL,
    "FullName" text NOT NULL,
    "Role" text NOT NULL,
    "IsActive" boolean NOT NULL,
    "CreatedAt" timestamp with time zone NOT NULL
);


ALTER TABLE public."Users" OWNER TO admin;

--
-- Name: __EFMigrationsHistory; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public."__EFMigrationsHistory" (
    "MigrationId" character varying(150) NOT NULL,
    "ProductVersion" character varying(32) NOT NULL
);


ALTER TABLE public."__EFMigrationsHistory" OWNER TO admin;

--
-- Data for Name: Accounts; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY public."Accounts" ("Id", "Code", "Name", "Type", "IsActive", "ParentAccountId") FROM stdin;
4f414fcf-737b-4e41-9030-8b5cd9e7cd4a	CASH	الخزينة الرئيسية	0	t	\N
4d1ca670-4097-4500-8c1a-3a3d0e1b4489	OPERATING_EXPENSES	المصروفات التشغيلية	4	t	\N
8880261e-5152-4c15-bd76-6682dd2b5c65	MAIN_TREASURY	حساب نظام - MAIN_TREASURY	0	t	\N
d9f5ba23-6613-4edc-ac98-694c3da99a40	SALES	إيرادات المبيعات	3	t	\N
9444dd9c-ee49-4b76-a202-106fd5c82382	COGS	تكلفة البضاعة المباعة	4	t	\N
0527f0e3-d92f-453a-8c6d-26bd67d90d77	INVENTORY	المخزون	0	t	\N
18b0eefe-8b44-46d8-a973-5f8c18f16261	ACCOUNTS_RECEIVABLE	ذمم العملاء المدينة	1	t	\N
\.


--
-- Data for Name: AuditLogs; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY public."AuditLogs" ("Id", "TableName", "RecordId", "Action", "OldValues", "NewValues", "CreatedBy", "CreatedAt") FROM stdin;
3e58b26b-db98-486f-a787-aaec85c91921	RefreshTokens	e469f3aa-0055-41bf-9b1e-a5ed1b738b1d	Modified	{"Revoked":null}	{"Revoked":"2026-03-02T01:15:49.4134688Z"}	System	2026-03-02 01:15:49.612388+00
98fcb6be-6691-4c2f-b1ef-e51d0d99bd00	RefreshTokens	890edceb-1181-46a0-836f-da9419e69b06	Added	\N	{"Id":"890edceb-1181-46a0-836f-da9419e69b06","Created":"2026-03-02T01:15:49.4542634Z","Expires":"2026-03-09T01:15:49.4544359Z","Revoked":null,"Token":"z2GffWfhAj4BsxyW0sm6E2DrUhXuOJ0d5G9knCU928kJF8FuSpHIf57o7iX2qsx5\\u002Buu3opbUgeMI45CJUO3y8w==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-02 01:15:49.585283+00
ee4084a8-8b86-47b6-8a55-28d050e1042f	JournalEntryLines	885e5c8d-27d8-4fe9-b947-c9c1659f74a3	Added	\N	{"Id":"885e5c8d-27d8-4fe9-b947-c9c1659f74a3","AccountId":"9444dd9c-ee49-4b76-a202-106fd5c82382","Credit":0,"Debit":17300.00,"Description":"\\u0625\\u062B\\u0628\\u0627\\u062A \\u062A\\u0643\\u0644\\u0641\\u0629 \\u0627\\u0644\\u0628\\u0636\\u0627\\u0639\\u0629 \\u0627\\u0644\\u0645\\u0628\\u0627\\u0639\\u0629 \\u0644\\u0641\\u0627\\u062A\\u0648\\u0631\\u0629 INV-20260302011751-8313","JournalEntryId":"d58bb39c-ea0c-4d0f-9cdb-71ec8f05f75c"}	System	2026-03-02 01:17:52.163102+00
f013f4bb-ec19-4ba5-963b-fa12af06d4eb	JournalEntries	d58bb39c-ea0c-4d0f-9cdb-71ec8f05f75c	Added	\N	{"Id":"d58bb39c-ea0c-4d0f-9cdb-71ec8f05f75c","CreatedBy":"admin","Date":"2026-03-02T01:17:52.1490926Z","Description":"\\u0625\\u062B\\u0628\\u0627\\u062A \\u062A\\u0643\\u0644\\u0641\\u0629 \\u0627\\u0644\\u0628\\u0636\\u0627\\u0639\\u0629 \\u0627\\u0644\\u0645\\u0628\\u0627\\u0639\\u0629 \\u0644\\u0641\\u0627\\u062A\\u0648\\u0631\\u0629 INV-20260302011751-8313","IsClosed":false,"Reference":"INV-20260302011751-8313","VoucherNumber":"JV-20260302-5980"}	admin	2026-03-02 01:17:52.163129+00
22027118-8459-4633-85f4-9ba905522134	RefreshTokens	2c89f719-9ddd-4a86-96fe-acb6a76333a1	Added	\N	{"Id":"2c89f719-9ddd-4a86-96fe-acb6a76333a1","Created":"2026-03-05T22:14:42.4458683Z","Expires":"2026-03-12T22:14:42.4459147Z","Revoked":null,"Token":"WRe\\u002BrBxQfn5o0DlZnEAsx7T6mfIIFExq6QxGlQzMgqTH/RqznRgInSN8zvWI0UZODx306YPLrXNJyJxBs4z7mA==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-05 22:14:42.507219+00
3cafbad1-fd3e-4f61-8d73-741970059a1f	RefreshTokens	1db2aefb-c6bb-4f75-a588-9f67606ed5a6	Modified	{"Revoked":null}	{"Revoked":"2026-03-05T22:14:42.4290888Z"}	System	2026-03-05 22:14:42.527871+00
55f00623-3590-414d-9053-82c0ce3338e6	InvoiceItems	7942b4d9-784c-4df7-a377-2106da83d555	Added	\N	{"Id":"7942b4d9-784c-4df7-a377-2106da83d555","InvoiceId":"12df2e36-e66e-4a8d-bff5-ad445a848cb1","ProductId":"6e658f48-e69a-434e-a00a-dfda36e45937","Quantity":1,"UnitPrice":8900.00}	System	2026-03-05 22:18:35.430179+00
61d6ed42-b006-46c7-923f-8c47c4379d5f	Products	c1db1d0e-d3c1-4488-8a06-1c82ed21264e	Modified	{"Category":"\\u0623\\u062C\\u0647\\u0632\\u0629 \\u0635\\u063A\\u064A\\u0631\\u0629","CreatedAt":"2026-03-04T00:14:43.653006Z","Description":null,"ExpiryDate":null,"GlobalBarcode":"850013","ImageUrl":"/uploads/products/kettle.jpg","InternalBarcode":"PROD5013","IsActive":true,"MinStockAlert":5,"Name":"\\u0643\\u0627\\u062A\\u0644 (\\u063A\\u0644\\u0627\\u064A\\u0629 \\u0645\\u064A\\u0627\\u0647) \\u0643\\u064A\\u0646\\u0648\\u0648\\u062F \\u0633\\u0639\\u0629 1.7 \\u0644\\u062A\\u0631","Price":950.00,"PurchasePrice":760.00,"StockQuantity":48,"UpdatedAt":"2026-03-04T00:14:43.653006Z","WholesalePrice":855.00}	{"Category":"\\u0623\\u062C\\u0647\\u0632\\u0629 \\u0635\\u063A\\u064A\\u0631\\u0629","CreatedAt":"2026-03-04T00:14:43.653006Z","Description":null,"ExpiryDate":null,"GlobalBarcode":"850013","ImageUrl":"/uploads/products/kettle.jpg","InternalBarcode":"PROD5013","IsActive":true,"MinStockAlert":5,"Name":"\\u0643\\u0627\\u062A\\u0644 (\\u063A\\u0644\\u0627\\u064A\\u0629 \\u0645\\u064A\\u0627\\u0647) \\u0643\\u064A\\u0646\\u0648\\u0648\\u062F \\u0633\\u0639\\u0629 1.7 \\u0644\\u062A\\u0631","Price":950.00,"PurchasePrice":760.00,"StockQuantity":48,"UpdatedAt":"2026-03-04T00:14:43.653006Z","WholesalePrice":855.00}	System	2026-03-05 22:18:35.44804+00
630a29e9-a4bb-45ea-bffe-6e95e2d05505	Products	90706a3a-181e-46c5-8aee-4eef92e3d651	Modified	{"Category":"\\u0623\\u062C\\u0647\\u0632\\u0629 \\u0635\\u063A\\u064A\\u0631\\u0629","CreatedAt":"2026-03-04T00:14:43.653006Z","Description":null,"ExpiryDate":null,"GlobalBarcode":"850017","ImageUrl":"/uploads/products/shaver.jpg","InternalBarcode":"PROD5017","IsActive":true,"MinStockAlert":5,"Name":"\\u0645\\u0627\\u0643\\u064A\\u0646\\u0629 \\u062D\\u0644\\u0627\\u0642\\u0629 \\u0628\\u0631\\u0627\\u0648\\u0646 \\u0644\\u0644\\u0631\\u062C\\u0627\\u0644","Price":1500.00,"PurchasePrice":1200.00,"StockQuantity":48,"UpdatedAt":"2026-03-04T00:14:43.653006Z","WholesalePrice":1350.00}	{"Category":"\\u0623\\u062C\\u0647\\u0632\\u0629 \\u0635\\u063A\\u064A\\u0631\\u0629","CreatedAt":"2026-03-04T00:14:43.653006Z","Description":null,"ExpiryDate":null,"GlobalBarcode":"850017","ImageUrl":"/uploads/products/shaver.jpg","InternalBarcode":"PROD5017","IsActive":true,"MinStockAlert":5,"Name":"\\u0645\\u0627\\u0643\\u064A\\u0646\\u0629 \\u062D\\u0644\\u0627\\u0642\\u0629 \\u0628\\u0631\\u0627\\u0648\\u0646 \\u0644\\u0644\\u0631\\u062C\\u0627\\u0644","Price":1500.00,"PurchasePrice":1200.00,"StockQuantity":48,"UpdatedAt":"2026-03-04T00:14:43.653006Z","WholesalePrice":1350.00}	System	2026-03-05 22:18:35.43022+00
7f40796a-cb89-4106-b617-cf975ff5d2a2	InvoiceItems	18683d94-b7e8-4ed5-8328-7d295c22c03d	Added	\N	{"Id":"18683d94-b7e8-4ed5-8328-7d295c22c03d","InvoiceId":"12df2e36-e66e-4a8d-bff5-ad445a848cb1","ProductId":"90706a3a-181e-46c5-8aee-4eef92e3d651","Quantity":1,"UnitPrice":1500.00}	System	2026-03-05 22:18:35.422093+00
a229a20a-1d31-4e94-8b04-6ad13bdfd755	Products	6e658f48-e69a-434e-a00a-dfda36e45937	Modified	{"Category":"\\u0623\\u062C\\u0647\\u0632\\u0629 \\u0635\\u063A\\u064A\\u0631\\u0629","CreatedAt":"2026-03-04T00:14:43.653006Z","Description":null,"ExpiryDate":null,"GlobalBarcode":"850016","ImageUrl":"/uploads/products/fryer.jpg","InternalBarcode":"PROD5016","IsActive":true,"MinStockAlert":5,"Name":"\\u0642\\u0644\\u0627\\u064A\\u0629 \\u0628\\u062F\\u0648\\u0646 \\u0632\\u064A\\u062A (\\u0627\\u064A\\u0631\\u0641\\u0631\\u0627\\u064A\\u0631) \\u0641\\u064A\\u0644\\u064A\\u0628\\u0633","Price":8900.00,"PurchasePrice":7120.00,"StockQuantity":48,"UpdatedAt":"2026-03-04T00:14:43.653006Z","WholesalePrice":8010.00}	{"Category":"\\u0623\\u062C\\u0647\\u0632\\u0629 \\u0635\\u063A\\u064A\\u0631\\u0629","CreatedAt":"2026-03-04T00:14:43.653006Z","Description":null,"ExpiryDate":null,"GlobalBarcode":"850016","ImageUrl":"/uploads/products/fryer.jpg","InternalBarcode":"PROD5016","IsActive":true,"MinStockAlert":5,"Name":"\\u0642\\u0644\\u0627\\u064A\\u0629 \\u0628\\u062F\\u0648\\u0646 \\u0632\\u064A\\u062A (\\u0627\\u064A\\u0631\\u0641\\u0631\\u0627\\u064A\\u0631) \\u0641\\u064A\\u0644\\u064A\\u0628\\u0633","Price":8900.00,"PurchasePrice":7120.00,"StockQuantity":48,"UpdatedAt":"2026-03-04T00:14:43.653006Z","WholesalePrice":8010.00}	System	2026-03-05 22:18:35.448173+00
a9cf0ef9-aece-4c74-b4a3-1f8d4fde7a2c	Customers	23ffdac1-1be6-473a-ae4d-fd795c8e8a64	Modified	{"TotalPaid":0.00,"TotalPurchases":0.00}	{"TotalPaid":5000.00,"TotalPurchases":11350.00}	System	2026-03-05 22:18:35.448272+00
db3226e5-f085-4bf9-8d0d-c0577862880b	Invoices	12df2e36-e66e-4a8d-bff5-ad445a848cb1	Added	\N	{"Id":"12df2e36-e66e-4a8d-bff5-ad445a848cb1","CashierId":"435668be-b38c-417d-979a-7ac88b8b4174","CreatedAt":"2026-03-05T22:18:35.0850249Z","CreatedBy":"admin","CustomerId":"23ffdac1-1be6-473a-ae4d-fd795c8e8a64","DiscountAmount":0.0,"DressDetails":null,"EventDate":null,"FittingDate":null,"InvoiceNo":"INV-20260305-00001","IsBridal":false,"Notes":null,"PaidAmount":5000.0,"PaymentType":2,"RemainingAmount":6350.00,"Status":0,"SubTotal":11350.00,"TotalAmount":11350.00,"VatAmount":0.00,"VatRate":0}	admin	2026-03-05 22:18:35.407686+00
e4f07a08-7248-4396-8fb3-efdc31dac541	InvoiceItems	c09807c2-f3fc-4bcc-a568-79ebd412da03	Added	\N	{"Id":"c09807c2-f3fc-4bcc-a568-79ebd412da03","InvoiceId":"12df2e36-e66e-4a8d-bff5-ad445a848cb1","ProductId":"c1db1d0e-d3c1-4488-8a06-1c82ed21264e","Quantity":1,"UnitPrice":950.00}	System	2026-03-05 22:18:35.429949+00
4bb9ba2d-0bac-45a4-897b-1207824b7141	Accounts	18b0eefe-8b44-46d8-a973-5f8c18f16261	Added	\N	{"Id":"18b0eefe-8b44-46d8-a973-5f8c18f16261","Code":"ACCOUNTS_RECEIVABLE","IsActive":true,"Name":"\\u0630\\u0645\\u0645 \\u0627\\u0644\\u0639\\u0645\\u0644\\u0627\\u0621 \\u0627\\u0644\\u0645\\u062F\\u064A\\u0646\\u0629","ParentAccountId":null,"Type":1}	System	2026-03-05 22:18:35.657842+00
259af7a5-0923-4020-9910-21685988c9cc	JournalEntryLines	e50fd380-64f5-460d-a270-a0474ccfc64d	Added	\N	{"Id":"e50fd380-64f5-460d-a270-a0474ccfc64d","AccountId":"4f414fcf-737b-4e41-9030-8b5cd9e7cd4a","Credit":0,"Debit":5000.0,"Description":"\\u0645\\u0628\\u064A\\u0639\\u0627\\u062A \\u0628\\u0627\\u0644\\u062A\\u0642\\u0633\\u064A\\u0637 - \\u0641\\u0627\\u062A\\u0648\\u0631\\u0629 INV-20260305-00001","JournalEntryId":"2846ae56-826d-4dc1-b406-f8004274f996"}	System	2026-03-05 22:18:35.762694+00
5d80d886-d194-4391-9651-7b21b57b31a8	RefreshTokens	7f68071d-9164-4fe8-85c7-f796b9b9e3db	Modified	{"Revoked":null}	{"Revoked":"2026-03-02T03:00:54.2448849Z"}	System	2026-03-02 03:00:54.344896+00
fe131d1b-ae1a-419a-881b-9b7aafb7baf3	RefreshTokens	44ad91db-51fa-4b4b-a6ac-52983b5c00a1	Added	\N	{"Id":"44ad91db-51fa-4b4b-a6ac-52983b5c00a1","Created":"2026-03-02T03:00:54.2630381Z","Expires":"2026-03-09T03:00:54.2631039Z","Revoked":null,"Token":"IHKyj3i9zg9xlVRu45ZWaIfmK2r65car0PgMmCAvi9ya9nq\\u002BDVatt5yKwyCbueuLroJ4KQgUrZFAYbtWQDO3Kw==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-02 03:00:54.324292+00
81a83fbc-e3ee-4761-85e2-dfb2ca6cc5a4	RefreshTokens	42aa5578-4f66-48dd-a6f4-ca2704db8235	Added	\N	{"Id":"42aa5578-4f66-48dd-a6f4-ca2704db8235","Created":"2026-03-02T03:00:54.2630332Z","Expires":"2026-03-09T03:00:54.263095Z","Revoked":null,"Token":"lfVbk5FZcV2YvR5wAK58k/cj6U9wKl48qd1PFvh2G/kHZ9b7u6C3OXgxBSpmj0BW/5EM4G4kN29PXP8jF\\u002BxnDw==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-02 03:00:54.323826+00
86711f50-d2cf-468f-81af-69396f200a3a	RefreshTokens	7f68071d-9164-4fe8-85c7-f796b9b9e3db	Modified	{"Revoked":null}	{"Revoked":"2026-03-02T03:00:54.244881Z"}	System	2026-03-02 03:00:54.344895+00
70cc87a4-89ac-4297-a58a-825d0c6b9a9c	RefreshTokens	2bcb688b-e05e-41a4-9971-b10fd249ef4a	Added	\N	{"Id":"2bcb688b-e05e-41a4-9971-b10fd249ef4a","Created":"2026-03-03T21:52:35.5867015Z","Expires":"2026-03-10T21:52:35.5868399Z","Revoked":null,"Token":"eojF7yrYR8LSNklFuF/uvm/\\u002BkUV/EBSdPcxPzTitHSj5QVI4BzQqV8Wy\\u002B\\u002B63O0ycs7ndmzTPVpuvThZWu4L\\u002Bhw==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-03 21:52:35.661304+00
791ba174-0cc8-474c-b814-68e3d96d629b	RefreshTokens	42aa5578-4f66-48dd-a6f4-ca2704db8235	Modified	{"Revoked":null}	{"Revoked":"2026-03-03T21:52:35.563273Z"}	System	2026-03-03 21:52:35.688894+00
3b9519b1-8bf7-48cd-962a-9107085ec242	JournalEntryLines	5e2540f5-d70e-4e2e-b888-10b1a739e3e1	Added	\N	{"Id":"5e2540f5-d70e-4e2e-b888-10b1a739e3e1","AccountId":"18b0eefe-8b44-46d8-a973-5f8c18f16261","Credit":0,"Debit":6350.00,"Description":"\\u0645\\u0628\\u064A\\u0639\\u0627\\u062A \\u0628\\u0627\\u0644\\u062A\\u0642\\u0633\\u064A\\u0637 - \\u0641\\u0627\\u062A\\u0648\\u0631\\u0629 INV-20260305-00001","JournalEntryId":"2846ae56-826d-4dc1-b406-f8004274f996"}	System	2026-03-05 22:18:35.762662+00
7f1fe532-ca60-4f65-9b65-bb9f52b7e804	JournalEntryLines	c0c780d9-c322-46c0-9931-b60e5ef808f9	Added	\N	{"Id":"c0c780d9-c322-46c0-9931-b60e5ef808f9","AccountId":"d9f5ba23-6613-4edc-ac98-694c3da99a40","Credit":11350.00,"Debit":0,"Description":"\\u0645\\u0628\\u064A\\u0639\\u0627\\u062A \\u0628\\u0627\\u0644\\u062A\\u0642\\u0633\\u064A\\u0637 - \\u0641\\u0627\\u062A\\u0648\\u0631\\u0629 INV-20260305-00001","JournalEntryId":"2846ae56-826d-4dc1-b406-f8004274f996"}	System	2026-03-05 22:18:35.762545+00
8ae822a7-c0d9-4bdd-b6bf-c7d0dca57c8d	JournalEntries	2846ae56-826d-4dc1-b406-f8004274f996	Added	\N	{"Id":"2846ae56-826d-4dc1-b406-f8004274f996","CreatedBy":"admin","Date":"2026-03-05T22:18:35.6821179Z","Description":"\\u0645\\u0628\\u064A\\u0639\\u0627\\u062A \\u0628\\u0627\\u0644\\u062A\\u0642\\u0633\\u064A\\u0637 - \\u0641\\u0627\\u062A\\u0648\\u0631\\u0629 INV-20260305-00001","IsClosed":false,"Reference":"INV-20260305-00001","VoucherNumber":"JV-20260305-2350"}	admin	2026-03-05 22:18:35.76272+00
136ed729-75f4-424e-94ab-cc43343c4977	JournalEntries	8ff1a7b0-e54d-4377-8975-d6b2bfb8d22b	Added	\N	{"Id":"8ff1a7b0-e54d-4377-8975-d6b2bfb8d22b","CreatedBy":"admin","Date":"2026-03-05T22:18:35.8369791Z","Description":"\\u0625\\u062B\\u0628\\u0627\\u062A \\u062A\\u0643\\u0644\\u0641\\u0629 \\u0627\\u0644\\u0628\\u0636\\u0627\\u0639\\u0629 \\u0627\\u0644\\u0645\\u0628\\u0627\\u0639\\u0629 \\u0644\\u0641\\u0627\\u062A\\u0648\\u0631\\u0629 INV-20260305-00001","IsClosed":false,"Reference":"INV-20260305-00001","VoucherNumber":"JV-20260305-7196"}	admin	2026-03-05 22:18:35.859115+00
1e133fc3-e1ea-469f-a0e1-c67bbc63c2c9	JournalEntryLines	c1671365-7a69-4832-baa0-a1ae79a65ff2	Added	\N	{"Id":"c1671365-7a69-4832-baa0-a1ae79a65ff2","AccountId":"0527f0e3-d92f-453a-8c6d-26bd67d90d77","Credit":9080.00,"Debit":0,"Description":"\\u0625\\u062B\\u0628\\u0627\\u062A \\u062A\\u0643\\u0644\\u0641\\u0629 \\u0627\\u0644\\u0628\\u0636\\u0627\\u0639\\u0629 \\u0627\\u0644\\u0645\\u0628\\u0627\\u0639\\u0629 \\u0644\\u0641\\u0627\\u062A\\u0648\\u0631\\u0629 INV-20260305-00001","JournalEntryId":"8ff1a7b0-e54d-4377-8975-d6b2bfb8d22b"}	System	2026-03-05 22:18:35.858953+00
58c80f11-2ab1-47cb-9e25-ad453b15f271	JournalEntryLines	44d19c94-2f4a-4ec6-b91d-9f8c24ba91c1	Added	\N	{"Id":"44d19c94-2f4a-4ec6-b91d-9f8c24ba91c1","AccountId":"9444dd9c-ee49-4b76-a202-106fd5c82382","Credit":0,"Debit":9080.00,"Description":"\\u0625\\u062B\\u0628\\u0627\\u062A \\u062A\\u0643\\u0644\\u0641\\u0629 \\u0627\\u0644\\u0628\\u0636\\u0627\\u0639\\u0629 \\u0627\\u0644\\u0645\\u0628\\u0627\\u0639\\u0629 \\u0644\\u0641\\u0627\\u062A\\u0648\\u0631\\u0629 INV-20260305-00001","JournalEntryId":"8ff1a7b0-e54d-4377-8975-d6b2bfb8d22b"}	System	2026-03-05 22:18:35.859073+00
937dd19e-b918-45c8-9b8f-629fb58cedcf	CashTransactions	9e3dddc3-eab0-4847-b3ee-8752aef4be4b	Added	\N	{"Id":"9e3dddc3-eab0-4847-b3ee-8752aef4be4b","Amount":5000.0,"CreatedBy":"admin","Date":"2026-03-05T22:18:35.7843738Z","Description":"\\u0645\\u0642\\u062F\\u0645 \\u0623\\u0642\\u0633\\u0627\\u0637 - \\u0641\\u0627\\u062A\\u0648\\u0631\\u0629 INV-20260305-00001","JournalEntryId":"2846ae56-826d-4dc1-b406-f8004274f996","ReceiptNumber":"INV-20260305-00001","TargetAccountId":"d9f5ba23-6613-4edc-ac98-694c3da99a40","Type":0}	admin	2026-03-05 22:18:35.859179+00
922ba367-acda-4777-899a-e2c437ec720f	Installments	a87505ec-af51-4205-841d-e8eef44a94f3	Added	\N	{"Id":"a87505ec-af51-4205-841d-e8eef44a94f3","Amount":1058.33,"CreatedAt":"2026-03-05T22:18:36.1414236Z","CustomerId":"23ffdac1-1be6-473a-ae4d-fd795c8e8a64","DueDate":"2026-05-04T21:18:22.899356Z","InvoiceId":"12df2e36-e66e-4a8d-bff5-ad445a848cb1","PaidAt":null,"ReminderSent":false,"Status":0}	System	2026-03-05 22:18:36.180344+00
9b87d4d5-b034-4cf0-a32f-c17ce4a3900e	Installments	1fe644d1-22de-4166-a5cc-06de5cf1a920	Added	\N	{"Id":"1fe644d1-22de-4166-a5cc-06de5cf1a920","Amount":1058.35,"CreatedAt":"2026-03-05T22:18:36.1414654Z","CustomerId":"23ffdac1-1be6-473a-ae4d-fd795c8e8a64","DueDate":"2026-09-04T21:18:22.899356Z","InvoiceId":"12df2e36-e66e-4a8d-bff5-ad445a848cb1","PaidAt":null,"ReminderSent":false,"Status":0}	System	2026-03-05 22:18:36.180508+00
9ba57a1f-33d6-47ef-bea2-9e4a9b35566a	Installments	09dff149-1eeb-45a4-8188-8ce511bf834e	Added	\N	{"Id":"09dff149-1eeb-45a4-8188-8ce511bf834e","Amount":1058.33,"CreatedAt":"2026-03-05T22:18:36.1409572Z","CustomerId":"23ffdac1-1be6-473a-ae4d-fd795c8e8a64","DueDate":"2026-04-04T22:18:22.899356Z","InvoiceId":"12df2e36-e66e-4a8d-bff5-ad445a848cb1","PaidAt":null,"ReminderSent":false,"Status":0}	System	2026-03-05 22:18:36.17685+00
b435cdee-788d-4fc1-8e1e-79c695b36814	Installments	5bd028d0-ebb3-4f1d-88bd-c122bec83fae	Added	\N	{"Id":"5bd028d0-ebb3-4f1d-88bd-c122bec83fae","Amount":1058.33,"CreatedAt":"2026-03-05T22:18:36.1414531Z","CustomerId":"23ffdac1-1be6-473a-ae4d-fd795c8e8a64","DueDate":"2026-06-04T21:18:22.899356Z","InvoiceId":"12df2e36-e66e-4a8d-bff5-ad445a848cb1","PaidAt":null,"ReminderSent":false,"Status":0}	System	2026-03-05 22:18:36.180421+00
b9377ca7-e587-41f1-8e8d-c1ae2bd0e139	Installments	34486ddc-15e1-4367-928f-1de2b2fd98af	Added	\N	{"Id":"34486ddc-15e1-4367-928f-1de2b2fd98af","Amount":1058.33,"CreatedAt":"2026-03-05T22:18:36.1414601Z","CustomerId":"23ffdac1-1be6-473a-ae4d-fd795c8e8a64","DueDate":"2026-08-04T21:18:22.899356Z","InvoiceId":"12df2e36-e66e-4a8d-bff5-ad445a848cb1","PaidAt":null,"ReminderSent":false,"Status":0}	System	2026-03-05 22:18:36.18049+00
f1cda160-2771-4572-bc5b-d597af6d69a0	Installments	48cb7f9f-4542-4f7f-84f8-2bcff16d41c3	Added	\N	{"Id":"48cb7f9f-4542-4f7f-84f8-2bcff16d41c3","Amount":1058.33,"CreatedAt":"2026-03-05T22:18:36.1414577Z","CustomerId":"23ffdac1-1be6-473a-ae4d-fd795c8e8a64","DueDate":"2026-07-04T21:18:22.899356Z","InvoiceId":"12df2e36-e66e-4a8d-bff5-ad445a848cb1","PaidAt":null,"ReminderSent":false,"Status":0}	System	2026-03-05 22:18:36.180446+00
008f88fa-bcc5-4b9c-a5fd-8b89b8a1c5ab	RefreshTokens	b8126428-0686-4378-809b-4caa08a41f89	Added	\N	{"Id":"b8126428-0686-4378-809b-4caa08a41f89","Created":"2026-03-03T21:52:35.5867014Z","Expires":"2026-03-10T21:52:35.5868289Z","Revoked":null,"Token":"PVJlK4Na47aM0Ny4efIUjzxDn/OIbDaamhLW6YahcATD9jxQ1JZpT4lHuyoZKTmNoKGOPNz589fxMlu9WltdAg==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-03 21:52:35.661286+00
22615472-9858-4dd6-a407-bfedbac6ff40	RefreshTokens	42aa5578-4f66-48dd-a6f4-ca2704db8235	Modified	{"Revoked":null}	{"Revoked":"2026-03-03T21:52:35.563277Z"}	System	2026-03-03 21:52:35.688362+00
962a290b-91e0-48a4-b2ec-dd138d355673	RefreshTokens	eb147d35-fe00-4a95-ae0b-3c2d158646cd	Modified	{"Revoked":null}	{"Revoked":"2026-03-05T22:45:17.6348844Z"}	System	2026-03-05 22:45:17.709448+00
c3b85283-d102-40e4-84aa-cd615e3e377d	RefreshTokens	6f940831-d313-4aab-b1f0-714da9f73d8e	Added	\N	{"Id":"6f940831-d313-4aab-b1f0-714da9f73d8e","Created":"2026-03-05T22:45:17.6482588Z","Expires":"2026-03-12T22:45:17.6483024Z","Revoked":null,"Token":"Y42Ychw9dQsJtPMuBePJjRRc5zjwOEpGdoFm9ulVrJS0hJXnFW4/Xpf8mCubakG8sdR1QAuWlIdiILpTA/rA/g==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-05 22:45:17.697582+00
1ac8b9d9-4bd9-42c8-a802-0239610af048	RefreshTokens	9fa40233-c60e-46c6-ad59-2486fb4ae63f	Added	\N	{"Id":"9fa40233-c60e-46c6-ad59-2486fb4ae63f","Created":"2026-03-07T01:09:29.6819559Z","Expires":"2026-03-14T01:09:29.6820821Z","Revoked":null,"Token":"igt6qDyE\\u002BBkMo\\u002BGlAuHQPpqWD2JIg0074trz\\u002B3fO9dbc6HyHA3g0KpeSe3dOyfHtANUcFR3bwnpOA3VfvsaOuw==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-07 01:09:29.74009+00
caf2845a-7186-48ea-b903-512d346fe80b	RefreshTokens	1581a0fa-7e3b-46b7-9a9c-fb362bc5b8fc	Modified	{"Revoked":null}	{"Revoked":"2026-03-07T01:09:29.6620039Z"}	System	2026-03-07 01:09:29.756463+00
79911356-b28c-41ce-be24-cc1c154f13b1	RefreshTokens	d263f311-f654-4d9d-9fc2-150f4640ddfa	Added	\N	{"Id":"d263f311-f654-4d9d-9fc2-150f4640ddfa","Created":"2026-03-07T22:05:05.9573975Z","Expires":"2026-03-14T22:05:05.9574703Z","Revoked":null,"Token":"veFi/rLa3k\\u002B4BbbGaEWMODkGLVpeezQv1ljcnQx\\u002BqoluNHd66IegJtsQJVcLzeTj/nvV6/YFR5sJHjkfZ987oQ==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-07 22:05:06.027043+00
b92192b2-003b-4b54-9065-7b67a2d907c8	RefreshTokens	8873d715-628a-45b8-9b60-03d91bb63e0d	Modified	{"Revoked":null}	{"Revoked":"2026-03-07T22:05:05.9327264Z"}	System	2026-03-07 22:05:06.048884+00
3a51328a-01b6-429e-ba41-5a3fb593cdaa	RefreshTokens	2b18a1d0-40df-4f04-b739-c65a109b0e2c	Added	\N	{"Id":"2b18a1d0-40df-4f04-b739-c65a109b0e2c","Created":"2026-03-08T02:42:15.4411229Z","Expires":"2026-03-15T02:42:15.4411925Z","Revoked":null,"Token":"p4XIfJKPSz14xoM3x58oKF8jqDYLlq4VMbvf0d/QU2lSBxDxY4yMBvamw2EuMLvE36XQAQLA\\u002BsPS4jjLZ\\u002BbDAA==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-08 02:42:15.548628+00
c2e38282-028d-45b4-8d35-54d566e9fb67	RefreshTokens	7edc28e5-124a-4400-afc3-647d56036321	Modified	{"Revoked":null}	{"Revoked":"2026-03-08T02:42:15.4153334Z"}	System	2026-03-08 02:42:15.574544+00
019d26f7-68aa-4396-9d9b-71e7b21b1a23	RefreshTokens	79b9f57e-94a3-4166-b638-055724ee0461	Added	\N	{"Id":"79b9f57e-94a3-4166-b638-055724ee0461","Created":"2026-03-09T00:25:35.7272299Z","Expires":"2026-03-16T00:25:35.7273306Z","Revoked":null,"Token":"LpIdl0CnXObXwK9jwTuW0IxqUg4z/PpMD9/hQAxaUnKGM7MjNYUK1qE0xhfpsmqkJbvdLKLAXI0HRn2UPYR4ZA==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-09 00:25:35.800737+00
b105e7ae-5e1b-4a02-a04e-fce06ba9bee7	RefreshTokens	21d4068a-4687-40ef-af4e-ebf733ed15b7	Modified	{"Revoked":null}	{"Revoked":"2026-03-09T00:25:35.704015Z"}	System	2026-03-09 00:25:35.825243+00
de8d876f-5888-4393-ac45-d1101766def5	RefreshTokens	399368c5-c4af-47a4-8dd8-f2a24db5882f	Added	\N	{"Id":"399368c5-c4af-47a4-8dd8-f2a24db5882f","Created":"2026-03-12T01:29:20.501512Z","Expires":"2026-03-19T01:29:20.5015701Z","Revoked":null,"Token":"LeLhIvQO4t3nCs18MuSLNV6sB5Q1er6Y8wlwrux97FTv5xhrrxyuVBUZz3CdVbGOoJRDwSPcbuj3NVnBEP6jTA==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-12 01:29:20.684268+00
378af6cf-2d59-44fe-b7cf-75486aabe924	RefreshTokens	8649ece6-5bc7-4cf4-aa54-6aa233a13fbf	Added	\N	{"Id":"8649ece6-5bc7-4cf4-aa54-6aa233a13fbf","Created":"2026-03-12T22:13:46.9490269Z","Expires":"2026-03-19T22:13:46.9490644Z","Revoked":null,"Token":"VGx//h6lpZgP5crKHuH0Mwndht0m271/FBp05spg1seL9Jj2vtrSosJhs9kaxRtvxpALC1\\u002B9SVqrZ9T3fAv8nw==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-12 22:13:47.028984+00
40c18541-b61e-4573-8b15-7173081a905c	Customers	d54415d2-3ea2-45dc-bfba-df9527eb0f6e	Modified	{"IsActive":true}	{"IsActive":false}	System	2026-03-03 21:57:51.883122+00
10b0c09d-0a19-45b7-ab5d-3aa2da8a043a	RefreshTokens	962259d5-be47-4d10-bd56-c42e67a250bf	Added	\N	{"Id":"962259d5-be47-4d10-bd56-c42e67a250bf","Created":"2026-03-05T23:31:03.1124681Z","Expires":"2026-03-12T23:31:03.1125253Z","Revoked":null,"Token":"dMfQdKBaVr6uCLPeH02IsvdNuC\\u002BH1C525kUEq6V9drTwxXwFdSfa5ef/juTrLGbVnTUDXbubkBZRle9P7EJpHg==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-05 23:31:03.174784+00
7c2e426c-bf8a-4a6b-bf10-752db6f20829	RefreshTokens	6f940831-d313-4aab-b1f0-714da9f73d8e	Modified	{"Revoked":null}	{"Revoked":"2026-03-05T23:31:03.091579Z"}	System	2026-03-05 23:31:03.189636+00
acd0e3cd-409b-420e-ae86-97967b22aa98	RefreshTokens	108f3a7e-59d4-493e-ae21-2c2a766c954f	Added	\N	{"Id":"108f3a7e-59d4-493e-ae21-2c2a766c954f","Created":"2026-03-07T03:07:27.1992279Z","Expires":"2026-03-14T03:07:27.1994329Z","Revoked":null,"Token":"SLQLOb2mto4YBv1sAHpL7s/iDn6rqHf/rqa4XZ8WFYAwv/ojrfcQbpJ2MsReHiuz97cLzW53wZfdl14KKaPEhw==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-07 03:07:27.616012+00
b5e8b3f2-eef4-45b5-b801-21a979ac7d18	RefreshTokens	9fa40233-c60e-46c6-ad59-2486fb4ae63f	Modified	{"Revoked":null}	{"Revoked":"2026-03-07T03:07:27.1761945Z"}	System	2026-03-07 03:07:28.144171+00
68446f8c-cde0-4e7f-a707-16cf6483251e	RefreshTokens	8873d715-628a-45b8-9b60-03d91bb63e0d	Modified	{"Revoked":null}	{"Revoked":"2026-03-07T22:05:05.9327219Z"}	System	2026-03-07 22:05:06.04861+00
07d43929-9be6-428a-83a8-49fec3a8cd7e	RefreshTokens	7edc28e5-124a-4400-afc3-647d56036321	Added	\N	{"Id":"7edc28e5-124a-4400-afc3-647d56036321","Created":"2026-03-07T22:05:05.9574286Z","Expires":"2026-03-14T22:05:05.9574947Z","Revoked":null,"Token":"NXTPUb/5jqdL\\u002ByyxjAe2TXu9/N9Ws8/djOumKoC2TPIkjjDtXHK9Vk0NI8/\\u002BUKoBBgxXOmQN4ajNmoWb8Bw45g==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-07 22:05:06.027001+00
d1e99349-31b0-4f9d-9eb4-7cae34777891	RefreshTokens	8873d715-628a-45b8-9b60-03d91bb63e0d	Modified	{"Revoked":null}	{"Revoked":"2026-03-07T22:05:05.9327308Z"}	System	2026-03-07 22:05:06.048868+00
75e6425a-705b-4a15-8256-f45207a88442	RefreshTokens	81c93523-0001-4fd7-9650-8404a0793d08	Added	\N	{"Id":"81c93523-0001-4fd7-9650-8404a0793d08","Created":"2026-03-07T22:05:05.957423Z","Expires":"2026-03-14T22:05:05.9574901Z","Revoked":null,"Token":"osEXxz9RsB7qzXTASbRtKsreDbqVSawViHA4tTys4u4MTo1UfJxTx/6C7gCGregqyB2TLndnTGrduORdxxTtvw==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-07 22:05:06.026231+00
30490e9d-3371-4dbb-a912-046eec9a6762	RefreshTokens	2b18a1d0-40df-4f04-b739-c65a109b0e2c	Modified	{"Revoked":null}	{"Revoked":"2026-03-08T03:16:28.9131399Z"}	System	2026-03-08 03:16:28.98555+00
667d0f24-1077-421e-a7eb-7e8354c72b4a	RefreshTokens	53d841dd-15b1-4aab-9e07-74cc1c0c206b	Added	\N	{"Id":"53d841dd-15b1-4aab-9e07-74cc1c0c206b","Created":"2026-03-08T03:16:28.9275149Z","Expires":"2026-03-15T03:16:28.9275638Z","Revoked":null,"Token":"QVN8iaI3rlJYHDUmfnO0SBqhLcFR2ybT5pPQk7LDJ4oRl1K9FNCTI1ePaLUDvpzzs97vnvcG9IIoImp8uLuzTg==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-08 03:16:28.975369+00
98cc8929-ff10-4f11-ab9c-21eea960b0fb	RefreshTokens	f993d631-62d7-47ed-b5b9-5bfbdefa4a8d	Added	\N	{"Id":"f993d631-62d7-47ed-b5b9-5bfbdefa4a8d","Created":"2026-03-09T00:25:35.7272527Z","Expires":"2026-03-16T00:25:35.7273369Z","Revoked":null,"Token":"NiLpGF8IE702vmjv5V2zSl5TLQe0IHxCBsaoN43vahLlEkrQRD0S2k0WQGw0GG/Tf\\u002BGCZEkqhXy1DLnZi6TfmQ==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-09 00:25:35.800748+00
bdacac5b-cf61-4422-8ee6-55bd26c83980	RefreshTokens	21d4068a-4687-40ef-af4e-ebf733ed15b7	Modified	{"Revoked":null}	{"Revoked":"2026-03-09T00:25:35.7040189Z"}	System	2026-03-09 00:25:35.825748+00
321ac4f2-d01a-48fb-b5cc-11b71129f336	RefreshTokens	399368c5-c4af-47a4-8dd8-f2a24db5882f	Modified	{"Revoked":null}	{"Revoked":"2026-03-12T02:00:01.0181308Z"}	System	2026-03-12 02:00:01.183385+00
6ad6a5df-1a25-45ad-979d-48d24201e1f7	RefreshTokens	a5c66ade-3ee0-4c8d-8b55-6bf2fc7de920	Added	\N	{"Id":"a5c66ade-3ee0-4c8d-8b55-6bf2fc7de920","Created":"2026-03-12T02:00:01.0506426Z","Expires":"2026-03-19T02:00:01.0507477Z","Revoked":null,"Token":"dSJ6xGRq65r7BL9mSGFEBIAHxKZYTdbgqGKL1dMPV7z19pCBU89rfN4SFy7bETWKJQW/o6M4ooDFBvv7fGTnfQ==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-12 02:00:01.1592+00
ad2b2ae8-66fa-47af-acd8-3214ad2406ad	RefreshTokens	1174a423-53d4-4228-b69a-abad2d3cdae2	Added	\N	{"Id":"1174a423-53d4-4228-b69a-abad2d3cdae2","Created":"2026-03-12T23:03:15.1278369Z","Expires":"2026-03-19T23:03:15.1278852Z","Revoked":null,"Token":"n0Dyx8WdViI5onE4wef17LP5CuP\\u002Bes24I1By/YmBzYCiDbDjpV9hV9RQdwDzcJrvmKv1OUOvJMfKcx7ETMu8hQ==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-12 23:03:15.251805+00
1a44b9b1-039c-4b54-b950-4739c1b37e9b	Products	6bff4c35-8695-4c85-aee8-fe9c7e643dc0	Added	\N	{"Id":"6bff4c35-8695-4c85-aee8-fe9c7e643dc0","Category":null,"CreatedAt":"2026-03-03T22:13:31.011994Z","Description":null,"ExpiryDate":null,"GlobalBarcode":null,"ImageUrl":null,"InternalBarcode":"200-2026-00005","IsActive":true,"MinStockAlert":0,"Name":"\\u0634\\u0627\\u0634\\u0629 \\u0633\\u0627\\u0645\\u0633\\u0648\\u0646\\u062C 43 \\u0628\\u0648\\u0635\\u0629","Price":11000.0,"PurchasePrice":10000.0,"StockQuantity":20,"UpdatedAt":null,"WholesalePrice":10000.0}	System	2026-03-03 22:13:31.079322+00
4abab506-69ef-4158-bb64-db05af67475b	RefreshTokens	815349cb-cb31-4976-8760-c3fa72d52a0e	Added	\N	{"Id":"815349cb-cb31-4976-8760-c3fa72d52a0e","Created":"2026-03-05T23:31:03.1128636Z","Expires":"2026-03-12T23:31:03.1128638Z","Revoked":null,"Token":"MUyWlaQZwxRv4xYdFhKuyOrpkn64E6MFziQthRqGo/xp5Rg8v338GSSqOEHoY5hFq6KeTcq1YPLAifKE1SPWQQ==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-05 23:31:03.17333+00
f0e8969c-7342-4051-9f95-11eb71bd7efd	RefreshTokens	6f940831-d313-4aab-b1f0-714da9f73d8e	Modified	{"Revoked":null}	{"Revoked":"2026-03-05T23:31:03.0939718Z"}	System	2026-03-05 23:31:03.189303+00
52afc029-51e9-4558-88e9-ce9936c9c8cb	RefreshTokens	9fa40233-c60e-46c6-ad59-2486fb4ae63f	Modified	{"Revoked":null}	{"Revoked":"2026-03-07T03:07:27.1770648Z"}	System	2026-03-07 03:07:28.144674+00
c6f5891f-d866-4e18-be79-4d7ed9cb86b7	RefreshTokens	8873d715-628a-45b8-9b60-03d91bb63e0d	Added	\N	{"Id":"8873d715-628a-45b8-9b60-03d91bb63e0d","Created":"2026-03-07T03:07:27.199231Z","Expires":"2026-03-14T03:07:27.1994413Z","Revoked":null,"Token":"6nzRwjuXW38u3kdjHK4t4XbdYkPgp7VFd3b2nmu6djTp2e7aqaeY47PHwgiw9Pb6aCWRSZcOk7T6VMGqodSkyw==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-07 03:07:27.615998+00
ae029217-ddeb-4897-8104-f5ffc67cf998	JournalEntryLines	ec5f2b91-650e-49e8-99b0-48e73c27159e	Added	\N	{"Id":"ec5f2b91-650e-49e8-99b0-48e73c27159e","AccountId":"4d1ca670-4097-4500-8c1a-3a3d0e1b4489","Credit":0,"Debit":500.0,"Description":"\\u0627\\u0643\\u0631\\u0627\\u0645\\u064A\\u0627\\u062A \\n","JournalEntryId":"f6853d11-9d1f-421d-bb29-7ba4f0c3d66a"}	System	2026-03-08 03:38:47.27295+00
cd5c813c-01f8-476d-b7a3-2b8e5b0ceaad	JournalEntries	f6853d11-9d1f-421d-bb29-7ba4f0c3d66a	Added	\N	{"Id":"f6853d11-9d1f-421d-bb29-7ba4f0c3d66a","CreatedBy":"admin","Date":"2026-03-08T03:38:46.7308044Z","Description":"\\u0627\\u0643\\u0631\\u0627\\u0645\\u064A\\u0627\\u062A \\n","IsClosed":false,"Reference":"EXP-20260308-d72e8a2a-45d5-4e77-8981-615e3a926451","VoucherNumber":"JV-20260308-9843"}	admin	2026-03-08 03:38:47.224478+00
e7614661-9c35-4979-9581-34ed6582deb1	JournalEntryLines	347927c8-d744-4efb-87f3-a6d0100117ae	Added	\N	{"Id":"347927c8-d744-4efb-87f3-a6d0100117ae","AccountId":"4f414fcf-737b-4e41-9030-8b5cd9e7cd4a","Credit":500.0,"Debit":0,"Description":"\\u0627\\u0643\\u0631\\u0627\\u0645\\u064A\\u0627\\u062A \\n","JournalEntryId":"f6853d11-9d1f-421d-bb29-7ba4f0c3d66a"}	System	2026-03-08 03:38:47.277882+00
03a55dbf-4587-4fe9-9e42-9b089b1770dd	RefreshTokens	21d4068a-4687-40ef-af4e-ebf733ed15b7	Modified	{"Revoked":null}	{"Revoked":"2026-03-09T00:25:35.7039609Z"}	System	2026-03-09 00:25:35.825248+00
bea2bf91-b6cb-4a15-b9c7-2807a78ff7fa	RefreshTokens	abce5216-1c46-48aa-851d-3aebd7c437cc	Added	\N	{"Id":"abce5216-1c46-48aa-851d-3aebd7c437cc","Created":"2026-03-09T00:25:35.7272298Z","Expires":"2026-03-16T00:25:35.7273218Z","Revoked":null,"Token":"hpamvzoUJHx1CqwCRN3zuKYSCARviMLdTKZthYjdnPZBjSsVZLD8aW7ib7bmCfIWd8Bvc/aIZej37CZX7RJgMg==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-09 00:25:35.800731+00
1dcb4993-b609-46bd-93ad-1d1bedaae2b5	RefreshTokens	3296296b-1741-45d3-a338-a322fefa9383	Added	\N	{"Id":"3296296b-1741-45d3-a338-a322fefa9383","Created":"2026-03-12T02:30:06.0428083Z","Expires":"2026-03-19T02:30:06.0428781Z","Revoked":null,"Token":"PYdBD60dpbT776hSgqApq42Cra01nLao1BYFzQoDS3/kVdQwQdf5kLZluswxlDEiY3BzqrQGtPSaO/jHK\\u002BGeew==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-12 02:30:06.116947+00
c772d2ae-b062-457b-afa3-1dbe9eec9bda	RefreshTokens	a5c66ade-3ee0-4c8d-8b55-6bf2fc7de920	Modified	{"Revoked":null}	{"Revoked":"2026-03-12T02:30:06.0080926Z"}	System	2026-03-12 02:30:06.132789+00
89ab18a0-c6bb-4795-9a84-e1e57105a5d8	CashTransactions	d226a633-0923-424f-a349-a65d19b6425d	Added	\N	{"Id":"d226a633-0923-424f-a349-a65d19b6425d","Amount":2000.0,"CreatedBy":"admin","Date":"2026-03-12T02:30:06.3732434Z","Description":"\\u0633\\u062F\\u0627\\u062F \\u0645\\u0646 \\u0627\\u0644\\u0639\\u0645\\u064A\\u0644: \\u0631\\u064A\\u0647\\u0627\\u0645  \\u2014 \\u0645\\u0646 \\u0627\\u0648\\u0644 \\u0642\\u0633\\u0637 ","JournalEntryId":null,"ReceiptNumber":null,"TargetAccountId":null,"Type":0}	admin	2026-03-12 02:30:06.424081+00
9af4f016-6d24-45cb-8edb-8859a1e78b37	Customers	23ffdac1-1be6-473a-ae4d-fd795c8e8a64	Modified	{"TotalPaid":5000.00}	{"TotalPaid":7000.00}	System	2026-03-12 02:30:06.432085+00
08e1fc57-9295-4999-a479-b7bde61ba6c8	Shifts	efbbeb4a-8673-4973-bb53-884876cb043d	Added	\N	{"Id":"efbbeb4a-8673-4973-bb53-884876cb043d","ActualCash":0,"CashierId":"435668be-b38c-417d-979a-7ac88b8b4174","Difference":0,"EndTime":null,"ExpectedCash":500.0,"Notes":null,"OpeningCash":500.0,"StartTime":"2026-03-12T23:10:42.6266337Z","Status":0,"TotalCashIn":0,"TotalCashOut":0,"TotalSales":0}	System	2026-03-12 23:10:42.645483+00
9046c104-493a-4836-b662-08d4de82947d	RefreshTokens	05e48349-cf3d-43c8-b7ee-1e6dcd996aeb	Added	\N	{"Id":"05e48349-cf3d-43c8-b7ee-1e6dcd996aeb","Created":"2026-03-03T22:26:21.5009839Z","Expires":"2026-03-10T22:26:21.5010768Z","Revoked":null,"Token":"wKTTSBOsc5oeyjQEqJaufNBNZ0o207dRfFLyQf0Irhs2z/jqfx7YcdDL5\\u002BldJjGFGaKjSIOP8bCRa1xYcod9BA==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-03 22:26:21.621865+00
aa322dad-7b39-4dd3-b9c6-55efdb7edc75	RefreshTokens	b8126428-0686-4378-809b-4caa08a41f89	Modified	{"Revoked":null}	{"Revoked":"2026-03-03T22:26:21.4705501Z"}	System	2026-03-03 22:26:21.676213+00
4447fdb7-d337-4d58-9874-8d1daafc1c9d	RefreshTokens	9e889f7c-34ba-4389-bb15-0b62a8a56b16	Added	\N	{"Id":"9e889f7c-34ba-4389-bb15-0b62a8a56b16","Created":"2026-03-06T00:06:00.5818146Z","Expires":"2026-03-13T00:06:00.5818148Z","Revoked":null,"Token":"459hqVG6e95raAeG\\u002B\\u002BliENp7feZTLoSvWUr4o1OW86w4SxG7/Jqxh2wmNV7amrRd599mSObPjkHlADA1Z5LYlA==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-06 00:06:00.599217+00
8107c46b-9bf2-4d33-9982-c45e73c56d4b	RefreshTokens	815349cb-cb31-4976-8760-c3fa72d52a0e	Modified	{"Revoked":null}	{"Revoked":"2026-03-06T00:06:00.5764408Z"}	System	2026-03-06 00:06:00.605955+00
26e35d18-6ffe-4b92-b253-240755a66cd2	RefreshTokens	9fa40233-c60e-46c6-ad59-2486fb4ae63f	Modified	{"Revoked":null}	{"Revoked":"2026-03-07T03:07:27.1763907Z"}	System	2026-03-07 03:07:28.14449+00
f37b04cf-600b-49a7-819b-5f39fd1d8380	RefreshTokens	0d3bd4ec-bb4d-4069-96d8-f47fc47b8049	Added	\N	{"Id":"0d3bd4ec-bb4d-4069-96d8-f47fc47b8049","Created":"2026-03-07T03:07:27.199221Z","Expires":"2026-03-14T03:07:27.1994242Z","Revoked":null,"Token":"ouvgb0lIKqKwhqqNM\\u002BZUhDIammJE12lC4sBXsvB4OHNcvaBomMBirltAXfBTtm6TWnskWOVy4/C0M4ajTA55VQ==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-07 03:07:27.615989+00
71e05786-c48a-4fb6-aa0d-6237272e5dd0	CashTransactions	e6985c23-b03d-420c-92f1-3d6aa7df2ddf	Added	\N	{"Id":"e6985c23-b03d-420c-92f1-3d6aa7df2ddf","Amount":500.0,"CreatedBy":"admin","Date":"2026-03-08T03:38:47.7702276Z","Description":"\\u0627\\u0643\\u0631\\u0627\\u0645\\u064A\\u0627\\u062A \\n","JournalEntryId":"f6853d11-9d1f-421d-bb29-7ba4f0c3d66a","ReceiptNumber":"REC-20260308-d72e8a2a-45d5-4e77-8981-615e3a926451","TargetAccountId":"4d1ca670-4097-4500-8c1a-3a3d0e1b4489","Type":1}	admin	2026-03-08 03:38:47.926805+00
bcde2a39-467a-4cd9-9939-e75c3ab51235	Expenses	d72e8a2a-45d5-4e77-8981-615e3a926451	Added	\N	{"Id":"d72e8a2a-45d5-4e77-8981-615e3a926451","Amount":500.0,"CategoryId":"44444444-4444-4444-4444-444444444444","CreatedBy":"admin","Date":"2026-03-08T03:38:46.4968071Z","Description":"\\u0627\\u0643\\u0631\\u0627\\u0645\\u064A\\u0627\\u062A \\n","JournalEntryId":"f6853d11-9d1f-421d-bb29-7ba4f0c3d66a"}	admin	2026-03-08 03:38:47.942528+00
008e4817-5d04-449c-90b9-628631c8091c	JournalEntries	a7065875-ead6-40c7-ab9c-b4d6708f3137	Added	\N	{"Id":"a7065875-ead6-40c7-ab9c-b4d6708f3137","CreatedBy":"admin","Date":"2026-03-08T03:38:55.6794742Z","Description":"\\u0627\\u0643\\u0631\\u0627\\u0645\\u064A\\u0627\\u062A \\n","IsClosed":false,"Reference":"EXP-20260308-e5027c1c-8811-4b93-b573-a671fe356ab4","VoucherNumber":"JV-20260308-5884"}	admin	2026-03-08 03:38:55.680291+00
2867b0bb-17c5-46b6-81df-cdd2c3dbeb6b	JournalEntryLines	14a5e311-b7b4-4b58-84f1-24e6b5e0ff04	Added	\N	{"Id":"14a5e311-b7b4-4b58-84f1-24e6b5e0ff04","AccountId":"4d1ca670-4097-4500-8c1a-3a3d0e1b4489","Credit":0,"Debit":500.0,"Description":"\\u0627\\u0643\\u0631\\u0627\\u0645\\u064A\\u0627\\u062A \\n","JournalEntryId":"a7065875-ead6-40c7-ab9c-b4d6708f3137"}	System	2026-03-08 03:38:55.680439+00
50eb3e87-f8af-47cb-a0cd-1fe09422ae69	JournalEntryLines	2b766e29-ef7a-4f60-9ff4-2b5ed15c726c	Added	\N	{"Id":"2b766e29-ef7a-4f60-9ff4-2b5ed15c726c","AccountId":"4f414fcf-737b-4e41-9030-8b5cd9e7cd4a","Credit":500.0,"Debit":0,"Description":"\\u0627\\u0643\\u0631\\u0627\\u0645\\u064A\\u0627\\u062A \\n","JournalEntryId":"a7065875-ead6-40c7-ab9c-b4d6708f3137"}	System	2026-03-08 03:38:55.680481+00
471041b0-9a17-4391-8996-2984af081428	RefreshTokens	f750c505-64fb-466f-ac3c-184f3fa4b171	Added	\N	{"Id":"f750c505-64fb-466f-ac3c-184f3fa4b171","Created":"2026-03-09T00:25:35.7272862Z","Expires":"2026-03-16T00:25:35.7273547Z","Revoked":null,"Token":"M07be1/46ljlWR3065EUeNi6NJ0byPi7ccaJoOZ9G5J2aHKKCalrQ0Hjde0OmSABJnC9zF\\u002Bk\\u002BcEjFOOWL4\\u002B5Rg==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-09 00:25:35.800766+00
53f1a909-6ecc-46a8-86ea-a843534204fd	RefreshTokens	21d4068a-4687-40ef-af4e-ebf733ed15b7	Modified	{"Revoked":null}	{"Revoked":"2026-03-09T00:25:35.7039683Z"}	System	2026-03-09 00:25:35.825748+00
7de9d7ab-108f-425e-9e4f-701d1ef804eb	RefreshTokens	0be0335f-a403-49e0-a1f6-1bb64e50c8b2	Added	\N	{"Id":"0be0335f-a403-49e0-a1f6-1bb64e50c8b2","Created":"2026-03-12T23:33:16.0853224Z","Expires":"2026-03-19T23:33:16.0853226Z","Revoked":null,"Token":"Uz9Ow6BW//91Y6zbn5nqrbf/rjLM4Rs3Nc2ZfsOzdurbUKlGZYguNOxiM0TyJmkFvlFpQ9myPsp6mIN6YcNkIg==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-12 23:33:16.088585+00
908c4ced-8b62-4a39-a9b4-24f4bcbf025b	RefreshTokens	1174a423-53d4-4228-b69a-abad2d3cdae2	Modified	{"Revoked":null}	{"Revoked":"2026-03-12T23:33:16.084198Z"}	System	2026-03-12 23:33:16.08868+00
f4c5909b-2ae9-4308-96e7-5d7b48c0a8e7	RefreshTokens	b8126428-0686-4378-809b-4caa08a41f89	Modified	{"Revoked":null}	{"Revoked":"2026-03-03T22:26:21.4752724Z"}	System	2026-03-03 22:26:21.677201+00
fd1c93dc-98d0-4ddf-8957-a6d9757d8c48	RefreshTokens	f0f9ad3d-469d-4ef7-9a91-937fc33b6dc6	Added	\N	{"Id":"f0f9ad3d-469d-4ef7-9a91-937fc33b6dc6","Created":"2026-03-03T22:26:21.5009782Z","Expires":"2026-03-10T22:26:21.5010851Z","Revoked":null,"Token":"k\\u002BR4Zm61YiO9pPMr3PdQDN2nBpuV3p6dPV1HYyXE8W837UTRdHP81W71ViXwJTUTvmFcCHBYLEZUPaO1/rSsdw==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-03 22:26:21.620792+00
62d0d3b0-f0d0-475a-a830-a9d26624152a	RefreshTokens	9e889f7c-34ba-4389-bb15-0b62a8a56b16	Modified	{"Revoked":null}	{"Revoked":"2026-03-06T00:52:04.7116467Z"}	System	2026-03-06 00:52:04.774666+00
92af852e-cbf4-4da5-81cf-f14edf05c010	RefreshTokens	1581a0fa-7e3b-46b7-9a9c-fb362bc5b8fc	Added	\N	{"Id":"1581a0fa-7e3b-46b7-9a9c-fb362bc5b8fc","Created":"2026-03-06T00:52:04.7311426Z","Expires":"2026-03-13T00:52:04.7311428Z","Revoked":null,"Token":"8Lqor1AGt9teZ7ZFvbgmzLcyf1vWhkNIKb/wSPtsMTdpqterubEWNZDBLoiOR9luTCrdPh67pPMLdd\\u002BacITwZQ==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-06 00:52:04.757671+00
3a36fb9e-bc0c-47b3-91fd-e01bea9790ca	Expenses	e5027c1c-8811-4b93-b573-a671fe356ab4	Added	\N	{"Id":"e5027c1c-8811-4b93-b573-a671fe356ab4","Amount":500.0,"CategoryId":"44444444-4444-4444-4444-444444444444","CreatedBy":"admin","Date":"2026-03-08T03:38:55.6625039Z","Description":"\\u0627\\u0643\\u0631\\u0627\\u0645\\u064A\\u0627\\u062A \\n","JournalEntryId":"a7065875-ead6-40c7-ab9c-b4d6708f3137"}	admin	2026-03-08 03:38:55.698704+00
d81cdedd-092c-4edf-9b05-62faa8849aae	CashTransactions	3998f909-f1e2-406b-8207-e8f35daf1fd2	Added	\N	{"Id":"3998f909-f1e2-406b-8207-e8f35daf1fd2","Amount":500.0,"CreatedBy":"admin","Date":"2026-03-08T03:38:55.6969218Z","Description":"\\u0627\\u0643\\u0631\\u0627\\u0645\\u064A\\u0627\\u062A \\n","JournalEntryId":"a7065875-ead6-40c7-ab9c-b4d6708f3137","ReceiptNumber":"REC-20260308-e5027c1c-8811-4b93-b573-a671fe356ab4","TargetAccountId":"4d1ca670-4097-4500-8c1a-3a3d0e1b4489","Type":1}	admin	2026-03-08 03:38:55.698034+00
0f54441b-da0a-444c-a1aa-841db4d3565c	RefreshTokens	44f58d8f-c54f-4a70-919a-2e81dcdb0f72	Added	\N	{"Id":"44f58d8f-c54f-4a70-919a-2e81dcdb0f72","Created":"2026-03-09T00:25:35.7272822Z","Expires":"2026-03-16T00:25:35.7273449Z","Revoked":null,"Token":"/HHHQv9EkjmvvurmAZrggVdNi4HY7/f9DsZiMJSA4q0\\u002BtlAVgKbtelMYZzgB3o0ExFFkywi\\u002BqJdwccTE5nGs5g==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-09 00:25:35.800757+00
a6151be5-9d45-4b89-a636-a33c026e36e2	RefreshTokens	21d4068a-4687-40ef-af4e-ebf733ed15b7	Modified	{"Revoked":null}	{"Revoked":"2026-03-09T00:25:35.7039528Z"}	System	2026-03-09 00:25:35.825748+00
65238226-f3f3-43c3-b9bd-b510a6f844fa	RefreshTokens	a240d0a0-6c6f-4882-9bcf-826136d03366	Added	\N	{"Id":"a240d0a0-6c6f-4882-9bcf-826136d03366","Created":"2026-03-03T22:59:00.868926Z","Expires":"2026-03-10T22:59:00.8689805Z","Revoked":null,"Token":"TTovToQWCU27XZF15/tI7/MRJwUIsE2SgaUljtos1G9SiDf33oYl6om7UBK5JNOZVcswopC67roFvcyl1Jn7fQ==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-03 22:59:00.932091+00
d8bb1dcb-9607-445c-827f-d37c52d4b6bd	RefreshTokens	05e48349-cf3d-43c8-b7ee-1e6dcd996aeb	Modified	{"Revoked":null}	{"Revoked":"2026-03-03T22:59:00.8522325Z"}	System	2026-03-03 22:59:00.949411+00
5a159ae2-d6f2-465d-bcbc-71af805f44e4	RefreshTokens	9e889f7c-34ba-4389-bb15-0b62a8a56b16	Modified	{"Revoked":null}	{"Revoked":"2026-03-06T00:52:04.7146236Z"}	System	2026-03-06 00:52:04.773018+00
c8e0c961-c583-4d68-a3a4-29abf3ba059d	RefreshTokens	2bdee9e0-3eed-48d8-82de-ff48cd7ceee5	Added	\N	{"Id":"2bdee9e0-3eed-48d8-82de-ff48cd7ceee5","Created":"2026-03-06T00:52:04.7271571Z","Expires":"2026-03-13T00:52:04.7271575Z","Revoked":null,"Token":"OYCIfQRJqOh7VksK01E7QMwwLLgTPUVLEerjYpYpfZJQYLZrpvSIT/YLoV0rN3PLT1z/5s8vQUCxPOZ6GCz3Iw==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-06 00:52:04.757809+00
1ea7a7a8-ad50-4e2a-ae86-df9439291c39	RefreshTokens	53d841dd-15b1-4aab-9e07-74cc1c0c206b	Modified	{"Revoked":null}	{"Revoked":"2026-03-08T03:49:26.9121055Z"}	System	2026-03-08 03:49:26.966356+00
a6b93572-bef4-4d03-9430-5490a4e99d3c	RefreshTokens	eb50ec09-39f9-4a66-b8d0-3158901acdef	Added	\N	{"Id":"eb50ec09-39f9-4a66-b8d0-3158901acdef","Created":"2026-03-08T03:49:26.9395567Z","Expires":"2026-03-15T03:49:26.939557Z","Revoked":null,"Token":"YRYo8kGLRyV2oKhRoiNDHdT6bkJkuJEbICAFtcocElkPPWpV9NToa2QxAXPZlVFegMMSGliDkStAZwX43zMwjA==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-08 03:49:26.963373+00
05bed4b6-a345-48ec-851d-66f6c7e33aac	RefreshTokens	f750c505-64fb-466f-ac3c-184f3fa4b171	Modified	{"Revoked":null}	{"Revoked":"2026-03-09T01:00:32.8530073Z"}	System	2026-03-09 01:00:32.964271+00
a800bc93-9317-4a98-97b4-cb1d4945f217	RefreshTokens	a8c7bff8-d08f-4cc2-81a8-2eecbd8cd189	Added	\N	{"Id":"a8c7bff8-d08f-4cc2-81a8-2eecbd8cd189","Created":"2026-03-09T01:00:32.8723657Z","Expires":"2026-03-16T01:00:32.8724127Z","Revoked":null,"Token":"D2PbigaVRMfAHLg9ZCz70LfrW4YBmH7C/MCVj7Rs9N7wV6Y22MlKz6gADVi8\\u002Br/NxJ6nSqaCvR3TXT80NSHrHg==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-09 01:00:32.947239+00
05da73b5-e435-4253-abe4-6067f5717955	RefreshTokens	bca27b58-6620-46a2-9583-2b9bdc37e9a2	Added	\N	{"Id":"bca27b58-6620-46a2-9583-2b9bdc37e9a2","Created":"2026-03-03T23:30:18.4905802Z","Expires":"2026-03-10T23:30:18.4906265Z","Revoked":null,"Token":"StUBCNJdxn/UohmfujnKD20TED/nXu5CCFlcbG37KCl9OjyQBrglrSU9Bzn3aHlG2U9gjpY32Pbx7/OBQezHmw==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-03 23:30:18.539123+00
ebe98409-4715-49fd-8764-9c77b8ea0ae5	RefreshTokens	a240d0a0-6c6f-4882-9bcf-826136d03366	Modified	{"Revoked":null}	{"Revoked":"2026-03-03T23:30:18.4753911Z"}	System	2026-03-03 23:30:18.552529+00
1aeb31cc-3d84-4873-a19d-bef4c4d9317c	RefreshTokens	53d841dd-15b1-4aab-9e07-74cc1c0c206b	Modified	{"Revoked":null}	{"Revoked":"2026-03-08T03:49:26.9120198Z"}	System	2026-03-08 03:49:26.965362+00
6724feb6-9c78-40c0-a406-a32935dbdeb4	RefreshTokens	cc54e3f3-977a-4968-bf98-e740839bb11e	Added	\N	{"Id":"cc54e3f3-977a-4968-bf98-e740839bb11e","Created":"2026-03-08T03:49:26.9392224Z","Expires":"2026-03-15T03:49:26.9392992Z","Revoked":null,"Token":"m0MPm4av2Y\\u002BV8DPzHGXN540paHLMFq91KDVwzj/UnvmO1Oa0IMOH7PfPPuapZ8YQrI5POUvg5K2mifVaf24kqQ==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-08 03:49:26.963006+00
b656fce7-aaae-40f1-8d8b-e4c11459af1a	RefreshTokens	a8c7bff8-d08f-4cc2-81a8-2eecbd8cd189	Modified	{"Revoked":null}	{"Revoked":"2026-03-09T01:58:58.6654595Z"}	System	2026-03-09 01:58:58.775331+00
d9077be4-91c7-4d1b-894d-12dd0bc0db7c	RefreshTokens	824d5088-f76f-4519-a04d-e5d51b4cac62	Added	\N	{"Id":"824d5088-f76f-4519-a04d-e5d51b4cac62","Created":"2026-03-09T01:58:58.68646Z","Expires":"2026-03-16T01:58:58.6865368Z","Revoked":null,"Token":"3DZyJ8I7yRbvxrywlI1VnImE2jU52jzATKdg7tIxyc6ZAc5jv\\u002BmF702vKxxu3hKfmAcinzDVbJhxLtuhbUIuKg==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-09 01:58:58.75725+00
72bcf378-de4a-49af-9fb7-b26e252a6fd6	RefreshTokens	bca27b58-6620-46a2-9583-2b9bdc37e9a2	Modified	{"Revoked":null}	{"Revoked":"2026-03-04T00:04:26.4070635Z"}	System	2026-03-04 00:04:26.489533+00
9fc5afee-a52c-409e-8d15-e73ae1db57a6	RefreshTokens	4df6849f-17a6-48f5-949a-d6e5387b9367	Added	\N	{"Id":"4df6849f-17a6-48f5-949a-d6e5387b9367","Created":"2026-03-04T00:04:26.422902Z","Expires":"2026-03-11T00:04:26.4229465Z","Revoked":null,"Token":"n0LCfZhtW3OkgGy3QJg8GBbn1e0qjMQ\\u002BT8Ii8frAWrqiEawwDGuqGsR2Rat8KV/M9XlviM6Xj86wpchTRzn\\u002BPQ==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-04 00:04:26.476947+00
3fb8e7af-0f9f-448b-87ad-bb0da96974e0	RefreshTokens	af0e5471-ec5f-4835-a323-dcbee6543b83	Added	\N	{"Id":"af0e5471-ec5f-4835-a323-dcbee6543b83","Created":"2026-03-08T03:49:26.9392478Z","Expires":"2026-03-15T03:49:26.9393458Z","Revoked":null,"Token":"OO6y8yFYjEyvplDOmrTadVl2NXm\\u002BDsC8mto2sXUkmw63selOlumJW3yja7h35Ey4TDyqb3rFsgeRYyNsD2qCvA==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-08 03:49:26.965349+00
e1bb5a93-96fc-4ab5-a3e0-116eee33ee91	RefreshTokens	53d841dd-15b1-4aab-9e07-74cc1c0c206b	Modified	{"Revoked":null}	{"Revoked":"2026-03-08T03:49:26.9092753Z"}	System	2026-03-08 03:49:26.965399+00
ba325db4-af2a-457c-b0f4-0a00aa890c48	RefreshTokens	072fc0b3-f836-49f4-ad20-ef4bf5f7452a	Added	\N	{"Id":"072fc0b3-f836-49f4-ad20-ef4bf5f7452a","Created":"2026-03-09T02:09:06.04707Z","Expires":"2026-03-16T02:09:06.0471017Z","Revoked":null,"Token":"oCG4/YuQn9n9nQo21Is\\u002BujOZf3PEPhi9ChNjCaN6fEN/Gr8k38YWraRUVIyaW6Wz8b7nSHyxOhu\\u002BsUHgp34e8g==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-09 02:09:06.114098+00
9db2cc7c-4c44-4fd1-908c-0d2a398fd9c5	RefreshTokens	4df6849f-17a6-48f5-949a-d6e5387b9367	Modified	{"Revoked":null}	{"Revoked":"2026-03-04T00:36:32.0199742Z"}	System	2026-03-04 00:36:32.12315+00
c27a125e-4955-4707-9108-45b5c4958655	RefreshTokens	2dadb04a-f1bf-4d0d-a32b-d2a31314b1e2	Added	\N	{"Id":"2dadb04a-f1bf-4d0d-a32b-d2a31314b1e2","Created":"2026-03-04T00:36:32.0402652Z","Expires":"2026-03-11T00:36:32.0405735Z","Revoked":null,"Token":"CrKlNCmVhS/U8jAXIi5iuOpL/I7oMjmP8GypWFoKSDNxbD5bhECqFFUblmITEueEpomG60AlTmeXYsw\\u002BWoOD9A==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-04 00:36:32.100898+00
a0ecd407-a3e5-4fa8-90e4-edc1a3106943	RefreshTokens	53d841dd-15b1-4aab-9e07-74cc1c0c206b	Modified	{"Revoked":null}	{"Revoked":"2026-03-08T03:49:26.9124657Z"}	System	2026-03-08 03:49:26.964818+00
fdf558cf-e961-49d5-a281-3c53fc08cca5	RefreshTokens	c49bb4f8-5f53-4413-942b-a5bc9358036f	Added	\N	{"Id":"c49bb4f8-5f53-4413-942b-a5bc9358036f","Created":"2026-03-08T03:49:26.9395194Z","Expires":"2026-03-15T03:49:26.9395196Z","Revoked":null,"Token":"REQyg3HeJnPlPBh43D9uAv2Ds/7jOk0xpNpYNOzBl4408JhwNOoYri1mVS6S363/Mum\\u002Bk4oXW69S92gWpp4xvw==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-08 03:49:26.963361+00
1c2c24f5-3e6a-473b-8dc3-8f1ec2f30583	RefreshTokens	072fc0b3-f836-49f4-ad20-ef4bf5f7452a	Modified	{"Revoked":null}	{"Revoked":"2026-03-09T02:43:35.7513434Z"}	System	2026-03-09 02:43:35.87078+00
ff437669-9492-49e5-be3f-4df20b804790	RefreshTokens	e2aaf8b4-930d-4282-83ee-a25d045c75cb	Added	\N	{"Id":"e2aaf8b4-930d-4282-83ee-a25d045c75cb","Created":"2026-03-09T02:43:35.7716872Z","Expires":"2026-03-16T02:43:35.7717391Z","Revoked":null,"Token":"KS7WPfsC1935IxQoms22Enx3U2qmEGysTVvGp98kxDY845ga3AQuElZG\\u002B5IG7ADmHtZA85GH9qDrEGITF5W\\u002Bcw==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-09 02:43:35.857084+00
e00f5569-0383-457e-9bf3-3f3c138e6dfe	Products	e438bb3f-925c-4533-9e0e-fa96051f4372	Modified	{"IsActive":true}	{"IsActive":false}	System	2026-03-04 00:42:35.244279+00
c524cf49-ef01-4280-9b8a-7f82ee93609d	Products	825c0802-5a04-436a-9e15-26fa144e5a36	Modified	{"IsActive":true}	{"IsActive":false}	System	2026-03-04 00:42:38.122498+00
163f340f-0902-48a1-a8f2-77028a0c1d7d	Products	795a986a-84a7-4567-be18-57b173d76d30	Modified	{"IsActive":true}	{"IsActive":false}	System	2026-03-04 00:42:41.722657+00
141f2e04-c157-4316-9bf7-f9aacb510d6f	RefreshTokens	53d841dd-15b1-4aab-9e07-74cc1c0c206b	Modified	{"Revoked":null}	{"Revoked":"2026-03-08T03:49:26.909262Z"}	System	2026-03-08 03:49:26.964818+00
ee6a8a91-f251-4497-a85e-60b196150aa6	RefreshTokens	21d4068a-4687-40ef-af4e-ebf733ed15b7	Added	\N	{"Id":"21d4068a-4687-40ef-af4e-ebf733ed15b7","Created":"2026-03-08T03:49:26.9392224Z","Expires":"2026-03-15T03:49:26.9395464Z","Revoked":null,"Token":"7KDH6LrhiMoZrNHyeAVoS4huEfrqPNT7ziwjLhQ7up\\u002B\\u002BhJNXDHK5SUVK0bqMbNenPOmcR4JQ7XwgJJR/eotbvQ==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-08 03:49:26.964349+00
0c3d7792-4d35-4eeb-8cc6-9249f5053673	RefreshTokens	16023bd6-e2fb-4762-963a-284b0540363a	Added	\N	{"Id":"16023bd6-e2fb-4762-963a-284b0540363a","Created":"2026-03-09T02:55:54.8474068Z","Expires":"2026-03-16T02:55:54.847407Z","Revoked":null,"Token":"OOaoltjxSlUvZ950h75qaDKx6T6Kau\\u002BK2KykSwIODPOr8FtQ\\u002BSub/xWWI37UVU/WTsqPA3b5Yz2MvS\\u002BIdMc1pQ==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-09 02:55:54.84787+00
6cef4724-22c0-485b-b319-0c6fbec09090	RefreshTokens	2dadb04a-f1bf-4d0d-a32b-d2a31314b1e2	Modified	{"Revoked":null}	{"Revoked":"2026-03-04T01:09:22.2496518Z"}	System	2026-03-04 01:09:22.256832+00
898c2500-59e8-4778-aaf0-0a98647f0b88	RefreshTokens	d4144e2c-bb66-469e-a814-cf7d6f8c3815	Added	\N	{"Id":"d4144e2c-bb66-469e-a814-cf7d6f8c3815","Created":"2026-03-04T01:09:22.2517231Z","Expires":"2026-03-11T01:09:22.2517233Z","Revoked":null,"Token":"vRDnrKMxBjiFaCMmFemGRUmt4i75FYgLlX491rR1JMyMd8rayUOGCFyQ6E5c8Lafv40DOvMrhbQs3Odgscvb7A==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-04 01:09:22.255198+00
8222a492-51e4-4a00-9095-5a7a3f0b4956	RefreshTokens	d4144e2c-bb66-469e-a814-cf7d6f8c3815	Modified	{"Revoked":null}	{"Revoked":"2026-03-04T02:22:14.082284Z"}	System	2026-03-04 02:22:14.121349+00
d61dbec9-9e80-4adb-b9ef-33c52823ce84	RefreshTokens	807292f7-98ff-47d2-97b4-3c34cbc06306	Added	\N	{"Id":"807292f7-98ff-47d2-97b4-3c34cbc06306","Created":"2026-03-04T02:22:14.0902069Z","Expires":"2026-03-11T02:22:14.0902071Z","Revoked":null,"Token":"kSeK8Ep3gQonjzs9UjehHYn3v8J4IAoSlP7Sx\\u002B1KmiPq7QR7N/KUSLuHX2BcD7H/svQ8ELuCfE3jXigVVKjy\\u002Bg==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-04 02:22:14.110374+00
5e0cebdf-f39b-4b1c-8951-c77254a7b16d	RefreshTokens	1db2aefb-c6bb-4f75-a588-9f67606ed5a6	Added	\N	{"Id":"1db2aefb-c6bb-4f75-a588-9f67606ed5a6","Created":"2026-03-04T02:22:14.090207Z","Expires":"2026-03-11T02:22:14.0902072Z","Revoked":null,"Token":"YP7e5maZRQM8iYh31fezDxVD4xJWiKk9zH\\u002BMrV5rPvL2u123SvptAvZ22kyjYD\\u002BbBa5WzQ0ArJCkoO2Sye8XBg==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-04 02:22:14.111796+00
eaa75b30-cfa5-4523-bad0-8f7826c1ad64	RefreshTokens	d4144e2c-bb66-469e-a814-cf7d6f8c3815	Modified	{"Revoked":null}	{"Revoked":"2026-03-04T02:22:14.0804671Z"}	System	2026-03-04 02:22:14.121349+00
f41b2878-d958-40dd-adee-a3b1e40c6789	ShopSettings	32ca9b86-f8a5-42ae-9809-61e4b42248e2	Modified	{"Address":null,"Phone":null,"ReceiptFooter":null,"ShopName":"\\u0646\\u0638\\u0627\\u0645 \\u0625\\u062E\\u0644\\u0627\\u0635 POS","UpdatedAt":"2026-02-24T21:45:31.267255Z"}	{"Address":"\\u0627\\u0644\\u0645\\u062D\\u0645\\u0648\\u062F\\u064A\\u0629","Phone":"","ReceiptFooter":"\\u0627\\u0644\\u0627\\u062E\\u0644\\u0627\\u0635 \\u0644\\u062A\\u062C\\u0647\\u064A\\u0632 \\u0627\\u0644\\u0639\\u0631\\u0627\\u0626\\u0633","ShopName":"\\u0627\\u0644\\u0625\\u062E\\u0644\\u0627\\u0635","UpdatedAt":"2026-03-04T02:28:00.2219325Z"}	System	2026-03-04 02:28:00.256678+00
8bd1f93f-349c-4221-ae96-a2215aa7f024	Users	2aa14527-0386-4329-aacc-7cec30b5ade1	Added	\N	{"Id":"2aa14527-0386-4329-aacc-7cec30b5ade1","CreatedAt":"2026-03-04T02:30:22.714481Z","FullName":"Ali","IsActive":true,"PasswordHash":"$2a$12$OWP2evqOyoZjXriWvt0XK.4cZe8iSdewS.0TNAXg6zBcQ/UuKFXY.","Role":"Manager","Username":"ali"}	System	2026-03-04 02:30:23.166816+00
caf832db-9302-455a-8ffb-cdb1133800c7	Users	435668be-b38c-417d-979a-7ac88b8b4174	Modified	{"FullName":"\\u0645\\u062F\\u064A\\u0631 \\u0627\\u0644\\u0646\\u0638\\u0627\\u0645 \\u0627\\u0644\\u0623\\u0633\\u0627\\u0633\\u064A"}	{"FullName":"\\u0627\\u0644\\u0645\\u062F\\u064A\\u0631"}	System	2026-03-04 02:30:57.149374+00
13613e4e-653a-4fdc-9df4-1ffd3fc0b992	Customers	b55975ac-1769-4720-a059-6cf8e3760a3c	Added	\N	{"Id":"b55975ac-1769-4720-a059-6cf8e3760a3c","Address":null,"CreatedAt":"2026-03-04T02:32:02.1513575Z","IsActive":true,"Name":"\\u0645\\u0646\\u0627\\u0644","Notes":null,"Phone":"02164574","TotalPaid":0,"TotalPurchases":0}	System	2026-03-04 02:32:02.172488+00
12a99dc8-cc76-452c-81e5-0519ac387407	Products	c1db1d0e-d3c1-4488-8a06-1c82ed21264e	Modified	{"Category":"\\u0623\\u062C\\u0647\\u0632\\u0629 \\u0635\\u063A\\u064A\\u0631\\u0629","CreatedAt":"2026-03-04T00:14:43.653006Z","Description":null,"ExpiryDate":null,"GlobalBarcode":"850013","ImageUrl":"/uploads/products/kettle.jpg","InternalBarcode":"PROD5013","IsActive":true,"MinStockAlert":5,"Name":"\\u0643\\u0627\\u062A\\u0644 (\\u063A\\u0644\\u0627\\u064A\\u0629 \\u0645\\u064A\\u0627\\u0647) \\u0643\\u064A\\u0646\\u0648\\u0648\\u062F \\u0633\\u0639\\u0629 1.7 \\u0644\\u062A\\u0631","Price":950.00,"PurchasePrice":760.00,"StockQuantity":49,"UpdatedAt":"2026-03-04T00:14:43.653006Z","WholesalePrice":855.00}	{"Category":"\\u0623\\u062C\\u0647\\u0632\\u0629 \\u0635\\u063A\\u064A\\u0631\\u0629","CreatedAt":"2026-03-04T00:14:43.653006Z","Description":null,"ExpiryDate":null,"GlobalBarcode":"850013","ImageUrl":"/uploads/products/kettle.jpg","InternalBarcode":"PROD5013","IsActive":true,"MinStockAlert":5,"Name":"\\u0643\\u0627\\u062A\\u0644 (\\u063A\\u0644\\u0627\\u064A\\u0629 \\u0645\\u064A\\u0627\\u0647) \\u0643\\u064A\\u0646\\u0648\\u0648\\u062F \\u0633\\u0639\\u0629 1.7 \\u0644\\u062A\\u0631","Price":950.00,"PurchasePrice":760.00,"StockQuantity":49,"UpdatedAt":"2026-03-04T00:14:43.653006Z","WholesalePrice":855.00}	System	2026-03-04 02:33:00.487489+00
1d978f54-d724-4a65-a32a-13f1a3ffed9d	Products	90706a3a-181e-46c5-8aee-4eef92e3d651	Modified	{"Category":"\\u0623\\u062C\\u0647\\u0632\\u0629 \\u0635\\u063A\\u064A\\u0631\\u0629","CreatedAt":"2026-03-04T00:14:43.653006Z","Description":null,"ExpiryDate":null,"GlobalBarcode":"850017","ImageUrl":"/uploads/products/shaver.jpg","InternalBarcode":"PROD5017","IsActive":true,"MinStockAlert":5,"Name":"\\u0645\\u0627\\u0643\\u064A\\u0646\\u0629 \\u062D\\u0644\\u0627\\u0642\\u0629 \\u0628\\u0631\\u0627\\u0648\\u0646 \\u0644\\u0644\\u0631\\u062C\\u0627\\u0644","Price":1500.00,"PurchasePrice":1200.00,"StockQuantity":49,"UpdatedAt":"2026-03-04T00:14:43.653006Z","WholesalePrice":1350.00}	{"Category":"\\u0623\\u062C\\u0647\\u0632\\u0629 \\u0635\\u063A\\u064A\\u0631\\u0629","CreatedAt":"2026-03-04T00:14:43.653006Z","Description":null,"ExpiryDate":null,"GlobalBarcode":"850017","ImageUrl":"/uploads/products/shaver.jpg","InternalBarcode":"PROD5017","IsActive":true,"MinStockAlert":5,"Name":"\\u0645\\u0627\\u0643\\u064A\\u0646\\u0629 \\u062D\\u0644\\u0627\\u0642\\u0629 \\u0628\\u0631\\u0627\\u0648\\u0646 \\u0644\\u0644\\u0631\\u062C\\u0627\\u0644","Price":1500.00,"PurchasePrice":1200.00,"StockQuantity":49,"UpdatedAt":"2026-03-04T00:14:43.653006Z","WholesalePrice":1350.00}	System	2026-03-04 02:33:00.487405+00
2aec93b2-c507-43b9-9dd1-663e971d7e0c	Products	266bcbe5-4bb5-4e86-b5e6-0c72bf32a280	Modified	{"Category":"\\u0623\\u062C\\u0647\\u0632\\u0629 \\u0645\\u0646\\u0632\\u0644\\u064A\\u0629","CreatedAt":"2026-03-04T00:14:43.653006Z","Description":null,"ExpiryDate":null,"GlobalBarcode":"850002","ImageUrl":"/uploads/products/fridge.jpg","InternalBarcode":"PROD5002","IsActive":true,"MinStockAlert":5,"Name":"\\u062B\\u0644\\u0627\\u062C\\u0629 \\u0634\\u0627\\u0631\\u0628 \\u062F\\u064A\\u062C\\u064A\\u062A\\u0627\\u0644 18 \\u0642\\u062F\\u0645","Price":28000.00,"PurchasePrice":22400.00,"StockQuantity":49,"UpdatedAt":"2026-03-04T00:14:43.653006Z","WholesalePrice":25200.00}	{"Category":"\\u0623\\u062C\\u0647\\u0632\\u0629 \\u0645\\u0646\\u0632\\u0644\\u064A\\u0629","CreatedAt":"2026-03-04T00:14:43.653006Z","Description":null,"ExpiryDate":null,"GlobalBarcode":"850002","ImageUrl":"/uploads/products/fridge.jpg","InternalBarcode":"PROD5002","IsActive":true,"MinStockAlert":5,"Name":"\\u062B\\u0644\\u0627\\u062C\\u0629 \\u0634\\u0627\\u0631\\u0628 \\u062F\\u064A\\u062C\\u064A\\u062A\\u0627\\u0644 18 \\u0642\\u062F\\u0645","Price":28000.00,"PurchasePrice":22400.00,"StockQuantity":49,"UpdatedAt":"2026-03-04T00:14:43.653006Z","WholesalePrice":25200.00}	System	2026-03-04 02:33:00.487188+00
3096c9a6-ba50-4862-b604-b17827b37e21	Products	b7158a95-eafa-49cc-9510-42ba70e8d2b7	Modified	{"Category":"\\u0623\\u062C\\u0647\\u0632\\u0629 \\u0645\\u0646\\u0632\\u0644\\u064A\\u0629","CreatedAt":"2026-03-04T00:14:43.653006Z","Description":null,"ExpiryDate":null,"GlobalBarcode":"850001","ImageUrl":"/uploads/products/tv.png","InternalBarcode":"PROD5001","IsActive":true,"MinStockAlert":5,"Name":"\\u0634\\u0627\\u0634\\u0629 \\u0633\\u0627\\u0645\\u0633\\u0648\\u0646\\u062C \\u0633\\u0645\\u0627\\u0631\\u062A 50 \\u0628\\u0648\\u0635\\u0629","Price":11500.00,"PurchasePrice":9200.00,"StockQuantity":49,"UpdatedAt":"2026-03-04T00:14:43.653006Z","WholesalePrice":10350.00}	{"Category":"\\u0623\\u062C\\u0647\\u0632\\u0629 \\u0645\\u0646\\u0632\\u0644\\u064A\\u0629","CreatedAt":"2026-03-04T00:14:43.653006Z","Description":null,"ExpiryDate":null,"GlobalBarcode":"850001","ImageUrl":"/uploads/products/tv.png","InternalBarcode":"PROD5001","IsActive":true,"MinStockAlert":5,"Name":"\\u0634\\u0627\\u0634\\u0629 \\u0633\\u0627\\u0645\\u0633\\u0648\\u0646\\u062C \\u0633\\u0645\\u0627\\u0631\\u062A 50 \\u0628\\u0648\\u0635\\u0629","Price":11500.00,"PurchasePrice":9200.00,"StockQuantity":49,"UpdatedAt":"2026-03-04T00:14:43.653006Z","WholesalePrice":10350.00}	System	2026-03-04 02:33:00.486142+00
43019678-70d8-4abc-93ee-575ce6e4d09a	InvoiceItems	cd05bf6d-0f46-4ba7-9f2e-80b88253198c	Added	\N	{"Id":"cd05bf6d-0f46-4ba7-9f2e-80b88253198c","InvoiceId":"c2fb8408-714f-43dc-a8b3-915008f2d752","ProductId":"6e409bf9-3d54-4c49-a11c-0c31bb185324","Quantity":1,"UnitPrice":2300.00}	System	2026-03-04 02:33:00.484199+00
43fa0ed0-6bac-4630-a2ff-045bf24fee63	Products	b3b0e974-e2cf-4ca2-b954-a82be22aca50	Modified	{"Category":"\\u0623\\u062C\\u0647\\u0632\\u0629 \\u0645\\u0646\\u0632\\u0644\\u064A\\u0629","CreatedAt":"2026-03-04T00:14:43.653006Z","Description":null,"ExpiryDate":null,"GlobalBarcode":"850004","ImageUrl":"/uploads/products/stove.jpg","InternalBarcode":"PROD5004","IsActive":true,"MinStockAlert":5,"Name":"\\u0628\\u0648\\u062A\\u0627\\u062C\\u0627\\u0632 \\u064A\\u0648\\u0646\\u064A\\u0641\\u0631\\u0633\\u0627\\u0644 5 \\u0634\\u0639\\u0644\\u0629","Price":8500.00,"PurchasePrice":6800.00,"StockQuantity":49,"UpdatedAt":"2026-03-04T00:14:43.653006Z","WholesalePrice":7650.00}	{"Category":"\\u0623\\u062C\\u0647\\u0632\\u0629 \\u0645\\u0646\\u0632\\u0644\\u064A\\u0629","CreatedAt":"2026-03-04T00:14:43.653006Z","Description":null,"ExpiryDate":null,"GlobalBarcode":"850004","ImageUrl":"/uploads/products/stove.jpg","InternalBarcode":"PROD5004","IsActive":true,"MinStockAlert":5,"Name":"\\u0628\\u0648\\u062A\\u0627\\u062C\\u0627\\u0632 \\u064A\\u0648\\u0646\\u064A\\u0641\\u0631\\u0633\\u0627\\u0644 5 \\u0634\\u0639\\u0644\\u0629","Price":8500.00,"PurchasePrice":6800.00,"StockQuantity":49,"UpdatedAt":"2026-03-04T00:14:43.653006Z","WholesalePrice":7650.00}	System	2026-03-04 02:33:00.486583+00
4d9bf92d-784d-4ebd-8b39-e234ceb6de39	InvoiceItems	f3b80b17-b2da-4e1c-b99b-11eac92cf41f	Added	\N	{"Id":"f3b80b17-b2da-4e1c-b99b-11eac92cf41f","InvoiceId":"c2fb8408-714f-43dc-a8b3-915008f2d752","ProductId":"266bcbe5-4bb5-4e86-b5e6-0c72bf32a280","Quantity":1,"UnitPrice":28000.00}	System	2026-03-04 02:33:00.484336+00
588a0eec-9fc9-4ddd-996c-2d3591ddf037	InvoiceItems	3f232363-ab86-44c5-ba21-7dbe88134b79	Added	\N	{"Id":"3f232363-ab86-44c5-ba21-7dbe88134b79","InvoiceId":"c2fb8408-714f-43dc-a8b3-915008f2d752","ProductId":"6e658f48-e69a-434e-a00a-dfda36e45937","Quantity":1,"UnitPrice":8900.00}	System	2026-03-04 02:33:00.484426+00
604a0556-4297-46fd-8ac9-a9c66324fe0a	InvoiceItems	58c15efa-502c-4349-a1a8-f99e9b72cb7b	Added	\N	{"Id":"58c15efa-502c-4349-a1a8-f99e9b72cb7b","InvoiceId":"c2fb8408-714f-43dc-a8b3-915008f2d752","ProductId":"18ba4f41-d2df-4467-9c4a-54eb264b75e8","Quantity":1,"UnitPrice":17000.00}	System	2026-03-04 02:33:00.484313+00
609f5f17-fa5e-4b99-9945-678e5bf7928e	Products	6e658f48-e69a-434e-a00a-dfda36e45937	Modified	{"Category":"\\u0623\\u062C\\u0647\\u0632\\u0629 \\u0635\\u063A\\u064A\\u0631\\u0629","CreatedAt":"2026-03-04T00:14:43.653006Z","Description":null,"ExpiryDate":null,"GlobalBarcode":"850016","ImageUrl":"/uploads/products/fryer.jpg","InternalBarcode":"PROD5016","IsActive":true,"MinStockAlert":5,"Name":"\\u0642\\u0644\\u0627\\u064A\\u0629 \\u0628\\u062F\\u0648\\u0646 \\u0632\\u064A\\u062A (\\u0627\\u064A\\u0631\\u0641\\u0631\\u0627\\u064A\\u0631) \\u0641\\u064A\\u0644\\u064A\\u0628\\u0633","Price":8900.00,"PurchasePrice":7120.00,"StockQuantity":49,"UpdatedAt":"2026-03-04T00:14:43.653006Z","WholesalePrice":8010.00}	{"Category":"\\u0623\\u062C\\u0647\\u0632\\u0629 \\u0635\\u063A\\u064A\\u0631\\u0629","CreatedAt":"2026-03-04T00:14:43.653006Z","Description":null,"ExpiryDate":null,"GlobalBarcode":"850016","ImageUrl":"/uploads/products/fryer.jpg","InternalBarcode":"PROD5016","IsActive":true,"MinStockAlert":5,"Name":"\\u0642\\u0644\\u0627\\u064A\\u0629 \\u0628\\u062F\\u0648\\u0646 \\u0632\\u064A\\u062A (\\u0627\\u064A\\u0631\\u0641\\u0631\\u0627\\u064A\\u0631) \\u0641\\u064A\\u0644\\u064A\\u0628\\u0633","Price":8900.00,"PurchasePrice":7120.00,"StockQuantity":49,"UpdatedAt":"2026-03-04T00:14:43.653006Z","WholesalePrice":8010.00}	System	2026-03-04 02:33:00.487562+00
63529da7-0fa8-4adc-9d44-0a67560142ed	Products	4df65b55-bd74-4757-92d2-e456c8551ab3	Modified	{"Category":"\\u0623\\u062C\\u0647\\u0632\\u0629 \\u0645\\u0646\\u0632\\u0644\\u064A\\u0629","CreatedAt":"2026-03-04T00:14:43.653006Z","Description":null,"ExpiryDate":null,"GlobalBarcode":"850010","ImageUrl":"/uploads/products/heater.jpg","InternalBarcode":"PROD5010","IsActive":true,"MinStockAlert":5,"Name":"\\u0633\\u062E\\u0627\\u0646 \\u0645\\u064A\\u0627\\u0647 \\u063A\\u0627\\u0632 \\u062A\\u0648\\u0631\\u0646\\u064A\\u062F\\u0648 10 \\u0644\\u062A\\u0631","Price":3900.00,"PurchasePrice":3120.00,"StockQuantity":49,"UpdatedAt":"2026-03-04T00:14:43.653006Z","WholesalePrice":3510.00}	{"Category":"\\u0623\\u062C\\u0647\\u0632\\u0629 \\u0645\\u0646\\u0632\\u0644\\u064A\\u0629","CreatedAt":"2026-03-04T00:14:43.653006Z","Description":null,"ExpiryDate":null,"GlobalBarcode":"850010","ImageUrl":"/uploads/products/heater.jpg","InternalBarcode":"PROD5010","IsActive":true,"MinStockAlert":5,"Name":"\\u0633\\u062E\\u0627\\u0646 \\u0645\\u064A\\u0627\\u0647 \\u063A\\u0627\\u0632 \\u062A\\u0648\\u0631\\u0646\\u064A\\u062F\\u0648 10 \\u0644\\u062A\\u0631","Price":3900.00,"PurchasePrice":3120.00,"StockQuantity":49,"UpdatedAt":"2026-03-04T00:14:43.653006Z","WholesalePrice":3510.00}	System	2026-03-04 02:33:00.484474+00
63beab37-d914-4325-a172-527d2516f151	InvoiceItems	5ccf3859-25f4-4828-9bfa-df434dba8cf7	Added	\N	{"Id":"5ccf3859-25f4-4828-9bfa-df434dba8cf7","InvoiceId":"c2fb8408-714f-43dc-a8b3-915008f2d752","ProductId":"b3b0e974-e2cf-4ca2-b954-a82be22aca50","Quantity":1,"UnitPrice":8500.00}	System	2026-03-04 02:33:00.484281+00
7b283262-f967-49da-a32c-1ece7e89f64e	Products	28ccb74a-07d0-4860-bbf0-9a055657f410	Modified	{"Category":"\\u0623\\u062C\\u0647\\u0632\\u0629 \\u0635\\u063A\\u064A\\u0631\\u0629","CreatedAt":"2026-03-04T00:14:43.653006Z","Description":null,"ExpiryDate":null,"GlobalBarcode":"850012","ImageUrl":"/uploads/products/processor.jpg","InternalBarcode":"PROD5012","IsActive":true,"MinStockAlert":5,"Name":"\\u0645\\u062D\\u0636\\u0631 \\u0637\\u0639\\u0627\\u0645 (\\u0643\\u0628\\u0629) \\u0628\\u0631\\u0627\\u0648\\u0646 600 \\u0648\\u0627\\u062A","Price":3100.00,"PurchasePrice":2480.00,"StockQuantity":49,"UpdatedAt":"2026-03-04T00:14:43.653006Z","WholesalePrice":2790.00}	{"Category":"\\u0623\\u062C\\u0647\\u0632\\u0629 \\u0635\\u063A\\u064A\\u0631\\u0629","CreatedAt":"2026-03-04T00:14:43.653006Z","Description":null,"ExpiryDate":null,"GlobalBarcode":"850012","ImageUrl":"/uploads/products/processor.jpg","InternalBarcode":"PROD5012","IsActive":true,"MinStockAlert":5,"Name":"\\u0645\\u062D\\u0636\\u0631 \\u0637\\u0639\\u0627\\u0645 (\\u0643\\u0628\\u0629) \\u0628\\u0631\\u0627\\u0648\\u0646 600 \\u0648\\u0627\\u062A","Price":3100.00,"PurchasePrice":2480.00,"StockQuantity":49,"UpdatedAt":"2026-03-04T00:14:43.653006Z","WholesalePrice":2790.00}	System	2026-03-04 02:33:00.487268+00
8aa9302b-7e5c-42e0-941c-245e7308d26f	Products	18ba4f41-d2df-4467-9c4a-54eb264b75e8	Modified	{"Category":"\\u0623\\u062C\\u0647\\u0632\\u0629 \\u0645\\u0646\\u0632\\u0644\\u064A\\u0629","CreatedAt":"2026-03-04T00:14:43.653006Z","Description":null,"ExpiryDate":null,"GlobalBarcode":"850005","ImageUrl":"/uploads/products/ac.jpg","InternalBarcode":"PROD5005","IsActive":true,"MinStockAlert":5,"Name":"\\u062A\\u0643\\u064A\\u064A\\u0641 \\u062A\\u0648\\u0631\\u0646\\u064A\\u062F\\u0648 1.5 \\u062D\\u0635\\u0627\\u0646 \\u0633\\u0628\\u0644\\u064A\\u062A","Price":17000.00,"PurchasePrice":13600.00,"StockQuantity":49,"UpdatedAt":"2026-03-04T00:14:43.653006Z","WholesalePrice":15300.00}	{"Category":"\\u0623\\u062C\\u0647\\u0632\\u0629 \\u0645\\u0646\\u0632\\u0644\\u064A\\u0629","CreatedAt":"2026-03-04T00:14:43.653006Z","Description":null,"ExpiryDate":null,"GlobalBarcode":"850005","ImageUrl":"/uploads/products/ac.jpg","InternalBarcode":"PROD5005","IsActive":true,"MinStockAlert":5,"Name":"\\u062A\\u0643\\u064A\\u064A\\u0641 \\u062A\\u0648\\u0631\\u0646\\u064A\\u062F\\u0648 1.5 \\u062D\\u0635\\u0627\\u0646 \\u0633\\u0628\\u0644\\u064A\\u062A","Price":17000.00,"PurchasePrice":13600.00,"StockQuantity":49,"UpdatedAt":"2026-03-04T00:14:43.653006Z","WholesalePrice":15300.00}	System	2026-03-04 02:33:00.487081+00
a766784b-2558-483c-b228-0e2b00cd165a	InvoiceItems	fe89d172-27f1-47ef-a395-b4a1b8cf4e55	Added	\N	{"Id":"fe89d172-27f1-47ef-a395-b4a1b8cf4e55","InvoiceId":"c2fb8408-714f-43dc-a8b3-915008f2d752","ProductId":"c1db1d0e-d3c1-4488-8a06-1c82ed21264e","Quantity":1,"UnitPrice":950.00}	System	2026-03-04 02:33:00.484409+00
be2b5e2d-1173-4ca1-b69f-59b9028b4303	Products	6e409bf9-3d54-4c49-a11c-0c31bb185324	Modified	{"Category":"\\u0623\\u062C\\u0647\\u0632\\u0629 \\u0635\\u063A\\u064A\\u0631\\u0629","CreatedAt":"2026-03-04T00:14:43.653006Z","Description":null,"ExpiryDate":null,"GlobalBarcode":"850009","ImageUrl":"/uploads/products/iron.jpg","InternalBarcode":"PROD5009","IsActive":true,"MinStockAlert":5,"Name":"\\u0645\\u0643\\u0648\\u0627\\u0629 \\u0628\\u062E\\u0627\\u0631 \\u062A\\u064A\\u0641\\u0627\\u0644 2000 \\u0648\\u0627\\u062A","Price":2300.00,"PurchasePrice":1840.00,"StockQuantity":49,"UpdatedAt":"2026-03-04T00:14:43.653006Z","WholesalePrice":2070.00}	{"Category":"\\u0623\\u062C\\u0647\\u0632\\u0629 \\u0635\\u063A\\u064A\\u0631\\u0629","CreatedAt":"2026-03-04T00:14:43.653006Z","Description":null,"ExpiryDate":null,"GlobalBarcode":"850009","ImageUrl":"/uploads/products/iron.jpg","InternalBarcode":"PROD5009","IsActive":true,"MinStockAlert":5,"Name":"\\u0645\\u0643\\u0648\\u0627\\u0629 \\u0628\\u062E\\u0627\\u0631 \\u062A\\u064A\\u0641\\u0627\\u0644 2000 \\u0648\\u0627\\u062A","Price":2300.00,"PurchasePrice":1840.00,"StockQuantity":49,"UpdatedAt":"2026-03-04T00:14:43.653006Z","WholesalePrice":2070.00}	System	2026-03-04 02:33:00.486434+00
be884975-366f-408f-b89a-8f5ee6491465	InvoiceItems	086eadcb-2336-4973-a147-3cda99d77c5f	Added	\N	{"Id":"086eadcb-2336-4973-a147-3cda99d77c5f","InvoiceId":"c2fb8408-714f-43dc-a8b3-915008f2d752","ProductId":"90706a3a-181e-46c5-8aee-4eef92e3d651","Quantity":1,"UnitPrice":1500.00}	System	2026-03-04 02:33:00.484393+00
d1bb05bd-46ad-40b2-b77d-86206424c6ad	InvoiceItems	06368db0-17da-44e4-9c21-86654490f38f	Added	\N	{"Id":"06368db0-17da-44e4-9c21-86654490f38f","InvoiceId":"c2fb8408-714f-43dc-a8b3-915008f2d752","ProductId":"b7158a95-eafa-49cc-9510-42ba70e8d2b7","Quantity":1,"UnitPrice":11500.00}	System	2026-03-04 02:33:00.484073+00
da485db2-6059-4fab-bb54-de4491a695c2	InvoiceItems	c9a0628b-f7de-4d12-90f5-6a2ceff8b2ce	Added	\N	{"Id":"c9a0628b-f7de-4d12-90f5-6a2ceff8b2ce","InvoiceId":"c2fb8408-714f-43dc-a8b3-915008f2d752","ProductId":"4df65b55-bd74-4757-92d2-e456c8551ab3","Quantity":1,"UnitPrice":3900.00}	System	2026-03-04 02:33:00.47625+00
e35a052b-2b26-4d55-8195-04bbf6cd8e44	Invoices	c2fb8408-714f-43dc-a8b3-915008f2d752	Added	\N	{"Id":"c2fb8408-714f-43dc-a8b3-915008f2d752","CashierId":"435668be-b38c-417d-979a-7ac88b8b4174","CreatedAt":"2026-03-04T02:33:00.0048601Z","CreatedBy":"admin","CustomerId":"23ffdac1-1be6-473a-ae4d-fd795c8e8a64","DiscountAmount":0.0,"DressDetails":null,"EventDate":null,"FittingDate":null,"InvoiceNo":"INV-20260304-00001","IsBridal":false,"Notes":null,"PaidAmount":35000.0,"PaymentType":2,"RemainingAmount":50650.00,"Status":0,"SubTotal":85650.00,"TotalAmount":85650.00,"VatAmount":0.00,"VatRate":0}	admin	2026-03-04 02:33:00.472837+00
e5104451-1d1f-478c-af46-9aade99bbaba	InvoiceItems	97f6715d-91c2-4529-8d00-458994bb4fb4	Added	\N	{"Id":"97f6715d-91c2-4529-8d00-458994bb4fb4","InvoiceId":"c2fb8408-714f-43dc-a8b3-915008f2d752","ProductId":"28ccb74a-07d0-4860-bbf0-9a055657f410","Quantity":1,"UnitPrice":3100.00}	System	2026-03-04 02:33:00.484367+00
55203dfd-bc38-4cae-857f-70c15847be8f	JournalEntryLines	3f49e3bb-a7cd-4267-b230-7cf98f92b221	Added	\N	{"Id":"3f49e3bb-a7cd-4267-b230-7cf98f92b221","AccountId":"4f414fcf-737b-4e41-9030-8b5cd9e7cd4a","Credit":0,"Debit":35000.0,"Description":"\\u0645\\u0628\\u064A\\u0639\\u0627\\u062A \\u0646\\u0627\\u062A\\u062C\\u0629 \\u0639\\u0646 \\u0641\\u0627\\u062A\\u0648\\u0631\\u0629 INV-20260304-00001","JournalEntryId":"bc876b68-3043-4939-939b-0610dd177c10"}	System	2026-03-04 02:33:00.922843+00
a6eac6d4-11a3-4228-94b7-fe48df6e36f6	JournalEntryLines	169c1c5c-9cef-48d7-9a71-5679bee891bc	Added	\N	{"Id":"169c1c5c-9cef-48d7-9a71-5679bee891bc","AccountId":"d9f5ba23-6613-4edc-ac98-694c3da99a40","Credit":35000.0,"Debit":0,"Description":"\\u0645\\u0628\\u064A\\u0639\\u0627\\u062A \\u0646\\u0627\\u062A\\u062C\\u0629 \\u0639\\u0646 \\u0641\\u0627\\u062A\\u0648\\u0631\\u0629 INV-20260304-00001","JournalEntryId":"bc876b68-3043-4939-939b-0610dd177c10"}	System	2026-03-04 02:33:00.920717+00
b33ea3ff-c94e-445c-8c2a-5e59fbd14aae	JournalEntries	bc876b68-3043-4939-939b-0610dd177c10	Added	\N	{"Id":"bc876b68-3043-4939-939b-0610dd177c10","CreatedBy":"admin","Date":"2026-03-04T02:33:00.8143594Z","Description":"\\u0645\\u0628\\u064A\\u0639\\u0627\\u062A \\u0646\\u0627\\u062A\\u062C\\u0629 \\u0639\\u0646 \\u0641\\u0627\\u062A\\u0648\\u0631\\u0629 INV-20260304-00001","IsClosed":false,"Reference":"INV-20260304-00001","VoucherNumber":"JV-20260304-5035"}	admin	2026-03-04 02:33:00.922865+00
44b3a4e0-d414-4891-ab5a-9a6b3a7e49c2	CashTransactions	1ef07da4-799f-4d7b-9488-dbbddac8e2cb	Added	\N	{"Id":"1ef07da4-799f-4d7b-9488-dbbddac8e2cb","Amount":35000.0,"CreatedBy":"admin","Date":"2026-03-04T02:33:00.9485409Z","Description":"\\u0645\\u0628\\u064A\\u0639\\u0627\\u062A \\u0641\\u0627\\u062A\\u0648\\u0631\\u0629 INV-20260304-00001 - \\u0645\\u0642\\u062F\\u0645 \\u0642\\u0633\\u0637","JournalEntryId":"bc876b68-3043-4939-939b-0610dd177c10","ReceiptNumber":"INV-20260304-00001","TargetAccountId":"d9f5ba23-6613-4edc-ac98-694c3da99a40","Type":0}	admin	2026-03-04 02:33:01.031795+00
73bd9d6b-adcd-45dc-97ba-e364f1dd6811	JournalEntries	55957304-1841-469e-9640-1846bd5af07f	Added	\N	{"Id":"55957304-1841-469e-9640-1846bd5af07f","CreatedBy":"admin","Date":"2026-03-04T02:33:01.0123616Z","Description":"\\u0625\\u062B\\u0628\\u0627\\u062A \\u062A\\u0643\\u0644\\u0641\\u0629 \\u0627\\u0644\\u0628\\u0636\\u0627\\u0639\\u0629 \\u0627\\u0644\\u0645\\u0628\\u0627\\u0639\\u0629 \\u0644\\u0641\\u0627\\u062A\\u0648\\u0631\\u0629 INV-20260304-00001","IsClosed":false,"Reference":"INV-20260304-00001","VoucherNumber":"JV-20260304-7825"}	admin	2026-03-04 02:33:01.031759+00
8d78ad38-db40-436c-bd81-aefc34f8afdf	JournalEntryLines	e692c06c-0449-4e4a-8a0b-b90839cb67fb	Added	\N	{"Id":"e692c06c-0449-4e4a-8a0b-b90839cb67fb","AccountId":"9444dd9c-ee49-4b76-a202-106fd5c82382","Credit":0,"Debit":68520.00,"Description":"\\u0625\\u062B\\u0628\\u0627\\u062A \\u062A\\u0643\\u0644\\u0641\\u0629 \\u0627\\u0644\\u0628\\u0636\\u0627\\u0639\\u0629 \\u0627\\u0644\\u0645\\u0628\\u0627\\u0639\\u0629 \\u0644\\u0641\\u0627\\u062A\\u0648\\u0631\\u0629 INV-20260304-00001","JournalEntryId":"55957304-1841-469e-9640-1846bd5af07f"}	System	2026-03-04 02:33:01.031705+00
9d3f710b-a6f8-4bef-b50d-d72ce614a263	JournalEntryLines	92520003-3170-4bed-a471-1ff131d8e7a3	Added	\N	{"Id":"92520003-3170-4bed-a471-1ff131d8e7a3","AccountId":"0527f0e3-d92f-453a-8c6d-26bd67d90d77","Credit":68520.00,"Debit":0,"Description":"\\u0625\\u062B\\u0628\\u0627\\u062A \\u062A\\u0643\\u0644\\u0641\\u0629 \\u0627\\u0644\\u0628\\u0636\\u0627\\u0639\\u0629 \\u0627\\u0644\\u0645\\u0628\\u0627\\u0639\\u0629 \\u0644\\u0641\\u0627\\u062A\\u0648\\u0631\\u0629 INV-20260304-00001","JournalEntryId":"55957304-1841-469e-9640-1846bd5af07f"}	System	2026-03-04 02:33:01.031616+00
28efcf44-f2d3-4bdc-8fc6-8ccf4bacfe26	Installments	67202899-95d7-4c41-ae2a-cdbad970eb1e	Added	\N	{"Id":"67202899-95d7-4c41-ae2a-cdbad970eb1e","Amount":8441.67,"CreatedAt":"2026-03-04T02:33:01.3013025Z","CustomerId":"23ffdac1-1be6-473a-ae4d-fd795c8e8a64","DueDate":"2026-08-03T01:32:32.665616Z","InvoiceId":"c2fb8408-714f-43dc-a8b3-915008f2d752","PaidAt":null,"ReminderSent":false,"Status":0}	System	2026-03-04 02:33:01.358751+00
552f25f6-438a-4a67-aae9-32c07785af3b	Installments	189e9653-88b9-4f42-8d1e-d9b4ddac21b3	Added	\N	{"Id":"189e9653-88b9-4f42-8d1e-d9b4ddac21b3","Amount":8441.67,"CreatedAt":"2026-03-04T02:33:01.3006772Z","CustomerId":"23ffdac1-1be6-473a-ae4d-fd795c8e8a64","DueDate":"2026-04-03T02:32:32.665616Z","InvoiceId":"c2fb8408-714f-43dc-a8b3-915008f2d752","PaidAt":null,"ReminderSent":false,"Status":0}	System	2026-03-04 02:33:01.3567+00
5b13a47c-75da-4a20-8e19-ec888b0b1506	Installments	1b35895c-1c54-4ec4-b2ab-1c39847a1ea2	Added	\N	{"Id":"1b35895c-1c54-4ec4-b2ab-1c39847a1ea2","Amount":8441.67,"CreatedAt":"2026-03-04T02:33:01.3012898Z","CustomerId":"23ffdac1-1be6-473a-ae4d-fd795c8e8a64","DueDate":"2026-06-03T01:32:32.665616Z","InvoiceId":"c2fb8408-714f-43dc-a8b3-915008f2d752","PaidAt":null,"ReminderSent":false,"Status":0}	System	2026-03-04 02:33:01.358683+00
9712f94a-9587-4ff9-846a-3f005f1c7fb0	Installments	e8952d60-0e30-43c5-9ae8-0cab2742e369	Added	\N	{"Id":"e8952d60-0e30-43c5-9ae8-0cab2742e369","Amount":8441.67,"CreatedAt":"2026-03-04T02:33:01.3011039Z","CustomerId":"23ffdac1-1be6-473a-ae4d-fd795c8e8a64","DueDate":"2026-05-03T01:32:32.665616Z","InvoiceId":"c2fb8408-714f-43dc-a8b3-915008f2d752","PaidAt":null,"ReminderSent":false,"Status":0}	System	2026-03-04 02:33:01.358616+00
be06f2c8-20b5-4911-8a7f-cc98bc449069	Installments	d2ed94ab-c225-4525-a7a1-107b46342042	Added	\N	{"Id":"d2ed94ab-c225-4525-a7a1-107b46342042","Amount":8441.67,"CreatedAt":"2026-03-04T02:33:01.3013Z","CustomerId":"23ffdac1-1be6-473a-ae4d-fd795c8e8a64","DueDate":"2026-07-03T01:32:32.665616Z","InvoiceId":"c2fb8408-714f-43dc-a8b3-915008f2d752","PaidAt":null,"ReminderSent":false,"Status":0}	System	2026-03-04 02:33:01.358716+00
fcd7df15-2d0e-4d81-884b-fec8c6debcd0	Installments	1f8e516a-6d11-4963-82a3-7af7818332c0	Added	\N	{"Id":"1f8e516a-6d11-4963-82a3-7af7818332c0","Amount":8441.65,"CreatedAt":"2026-03-04T02:33:01.3013097Z","CustomerId":"23ffdac1-1be6-473a-ae4d-fd795c8e8a64","DueDate":"2026-09-03T01:32:32.665616Z","InvoiceId":"c2fb8408-714f-43dc-a8b3-915008f2d752","PaidAt":null,"ReminderSent":false,"Status":0}	System	2026-03-04 02:33:01.358768+00
4af0fdc9-a813-4e33-8c3f-8c703ccefdfb	RefreshTokens	eb147d35-fe00-4a95-ae0b-3c2d158646cd	Added	\N	{"Id":"eb147d35-fe00-4a95-ae0b-3c2d158646cd","Created":"2026-03-05T22:14:42.44586Z","Expires":"2026-03-12T22:14:42.4459089Z","Revoked":null,"Token":"PYq7kzRWKpt/e2hXgiForORyosV//x7tvccfVhjX97nFHrum\\u002BJQxAFpacOJNh05q3w9eJrN2C6imU1z8XM8pig==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-05 22:14:42.507222+00
7adb24dc-fd62-43ff-aebb-1a4dde008f25	RefreshTokens	1db2aefb-c6bb-4f75-a588-9f67606ed5a6	Modified	{"Revoked":null}	{"Revoked":"2026-03-05T22:14:42.4290812Z"}	System	2026-03-05 22:14:42.527871+00
2eb8c7bf-878e-4f00-8fee-6348328648b6	RefreshTokens	7f68071d-9164-4fe8-85c7-f796b9b9e3db	Added	\N	{"Id":"7f68071d-9164-4fe8-85c7-f796b9b9e3db","Created":"2026-03-02T01:15:49.4542632Z","Expires":"2026-03-09T01:15:49.4543623Z","Revoked":null,"Token":"7cEVo54LWjezbgpRrun0Ym/pOpXZ\\u002BQSFJTG2/8Y7dwcxIA6I8EdP\\u002BWTs9bTqABc5gl7CEpXTq9qCAw4v\\u002BQpvjw==","UserId":"435668be-b38c-417d-979a-7ac88b8b4174"}	System	2026-03-02 01:15:49.584791+00
7f7947ce-7cd6-44b3-98e3-b992add6770a	RefreshTokens	e469f3aa-0055-41bf-9b1e-a5ed1b738b1d	Modified	{"Revoked":null}	{"Revoked":"2026-03-02T01:15:49.4134259Z"}	System	2026-03-02 01:15:49.612219+00
735f3fd5-1975-496a-995b-02d2843402f9	Accounts	8880261e-5152-4c15-bd76-6682dd2b5c65	Added	\N	{"Id":"8880261e-5152-4c15-bd76-6682dd2b5c65","Code":"MAIN_TREASURY","IsActive":true,"Name":"\\u062D\\u0633\\u0627\\u0628 \\u0646\\u0638\\u0627\\u0645 - MAIN_TREASURY","ParentAccountId":null,"Type":0}	System	2026-03-02 01:16:22.653271+00
e9e660ee-cc3b-4ed3-986b-3fc2bcf06c05	Customers	23ffdac1-1be6-473a-ae4d-fd795c8e8a64	Added	\N	{"Id":"23ffdac1-1be6-473a-ae4d-fd795c8e8a64","Address":null,"CreatedAt":"2026-03-02T01:17:08.5476002Z","IsActive":true,"Name":"\\u0631\\u064A\\u0647\\u0627\\u0645 ","Notes":null,"Phone":"01154798","TotalPaid":0,"TotalPurchases":0}	System	2026-03-02 01:17:08.568443+00
040a6bc0-1a0a-4860-a3d6-79c9fa8cf2f0	InvoiceItems	b5814aca-6342-4ddd-9370-d687a16ad1a2	Added	\N	{"Id":"b5814aca-6342-4ddd-9370-d687a16ad1a2","InvoiceId":"4fa6c4c1-ee47-48d2-a62c-9f1006e61b22","ProductId":"02654983-613d-47cf-b0d3-e0e5a625d4f4","Quantity":1,"UnitPrice":15300.00}	System	2026-03-02 01:17:51.745816+00
0aef1d86-e1f6-4dbf-b96f-703a7d604474	Products	02654983-613d-47cf-b0d3-e0e5a625d4f4	Modified	{"Category":"\\u0627\\u062C\\u0647\\u0632\\u0629 \\u0643\\u0647\\u0631\\u0628\\u0627\\u0626\\u064A\\u0629","CreatedAt":"2026-02-25T23:54:58.160073Z","Description":null,"ExpiryDate":null,"GlobalBarcode":"200-2026-00002","ImageUrl":null,"InternalBarcode":"200-2026-00002","IsActive":true,"MinStockAlert":5,"Name":"\\u0628\\u062A\\u0648\\u062C\\u0627\\u0632 \\u0627\\u064A\\u062F\\u064A\\u0627\\u0644 ","Price":15300.00,"PurchasePrice":14300.00,"StockQuantity":16,"UpdatedAt":null,"WholesalePrice":14300.00}	{"Category":"\\u0627\\u062C\\u0647\\u0632\\u0629 \\u0643\\u0647\\u0631\\u0628\\u0627\\u0626\\u064A\\u0629","CreatedAt":"2026-02-25T23:54:58.160073Z","Description":null,"ExpiryDate":null,"GlobalBarcode":"200-2026-00002","ImageUrl":null,"InternalBarcode":"200-2026-00002","IsActive":true,"MinStockAlert":5,"Name":"\\u0628\\u062A\\u0648\\u062C\\u0627\\u0632 \\u0627\\u064A\\u062F\\u064A\\u0627\\u0644 ","Price":15300.00,"PurchasePrice":14300.00,"StockQuantity":16,"UpdatedAt":null,"WholesalePrice":14300.00}	System	2026-03-02 01:17:51.76792+00
85688c07-7380-4311-a108-def6bdfb29c8	Invoices	4fa6c4c1-ee47-48d2-a62c-9f1006e61b22	Added	\N	{"Id":"4fa6c4c1-ee47-48d2-a62c-9f1006e61b22","CashierId":"435668be-b38c-417d-979a-7ac88b8b4174","CreatedAt":"2026-03-02T01:17:51.3188385Z","CreatedBy":"admin","CustomerId":null,"DiscountAmount":0.0,"DressDetails":null,"EventDate":null,"FittingDate":null,"InvoiceNo":"INV-20260302011751-8313","IsBridal":false,"Notes":null,"PaidAmount":5000.0,"PaymentType":2,"RemainingAmount":14300.00,"Status":0,"SubTotal":19300.00,"TotalAmount":19300.00,"VatAmount":0.00,"VatRate":0}	admin	2026-03-02 01:17:51.719618+00
8a65526c-6f5a-41c0-b632-a9e10594165c	Products	1ffccc5c-1359-4887-b431-23b2f7a0041d	Modified	{"Category":"\\u0627\\u062C\\u0647\\u0632\\u0629 \\u0643\\u0647\\u0631\\u0628\\u0627\\u0626\\u064A\\u0629","CreatedAt":"2026-02-25T23:53:29.804571Z","Description":null,"ExpiryDate":null,"GlobalBarcode":"200-2026-00001","ImageUrl":null,"InternalBarcode":"200-2026-00001","IsActive":true,"MinStockAlert":5,"Name":"\\u0634\\u0627\\u0634\\u0629 \\u062A\\u0648\\u0631\\u0646\\u064A\\u062F\\u0648 ","Price":4000.00,"PurchasePrice":3000.00,"StockQuantity":17,"UpdatedAt":null,"WholesalePrice":3000.00}	{"Category":"\\u0627\\u062C\\u0647\\u0632\\u0629 \\u0643\\u0647\\u0631\\u0628\\u0627\\u0626\\u064A\\u0629","CreatedAt":"2026-02-25T23:53:29.804571Z","Description":null,"ExpiryDate":null,"GlobalBarcode":"200-2026-00001","ImageUrl":null,"InternalBarcode":"200-2026-00001","IsActive":true,"MinStockAlert":5,"Name":"\\u0634\\u0627\\u0634\\u0629 \\u062A\\u0648\\u0631\\u0646\\u064A\\u062F\\u0648 ","Price":4000.00,"PurchasePrice":3000.00,"StockQuantity":17,"UpdatedAt":null,"WholesalePrice":3000.00}	System	2026-03-02 01:17:51.745914+00
d6b44f24-f9fd-46f6-b578-6f630896d458	InvoiceItems	66642719-60d7-4a47-847b-b9fda7e92f62	Added	\N	{"Id":"66642719-60d7-4a47-847b-b9fda7e92f62","InvoiceId":"4fa6c4c1-ee47-48d2-a62c-9f1006e61b22","ProductId":"1ffccc5c-1359-4887-b431-23b2f7a0041d","Quantity":1,"UnitPrice":4000.00}	System	2026-03-02 01:17:51.733967+00
2d6285e4-8173-4b74-9e4a-6fa901a6c810	Accounts	d9f5ba23-6613-4edc-ac98-694c3da99a40	Added	\N	{"Id":"d9f5ba23-6613-4edc-ac98-694c3da99a40","Code":"SALES","IsActive":true,"Name":"\\u0625\\u064A\\u0631\\u0627\\u062F\\u0627\\u062A \\u0627\\u0644\\u0645\\u0628\\u064A\\u0639\\u0627\\u062A","ParentAccountId":null,"Type":3}	System	2026-03-02 01:17:51.885333+00
3e809b2f-a597-4b7b-a8b1-d02cfc1bb57c	Accounts	9444dd9c-ee49-4b76-a202-106fd5c82382	Added	\N	{"Id":"9444dd9c-ee49-4b76-a202-106fd5c82382","Code":"COGS","IsActive":true,"Name":"\\u062A\\u0643\\u0644\\u0641\\u0629 \\u0627\\u0644\\u0628\\u0636\\u0627\\u0639\\u0629 \\u0627\\u0644\\u0645\\u0628\\u0627\\u0639\\u0629","ParentAccountId":null,"Type":4}	System	2026-03-02 01:17:51.900311+00
dc938176-ee74-4bbd-8dbb-0a37a9e63fae	Accounts	0527f0e3-d92f-453a-8c6d-26bd67d90d77	Added	\N	{"Id":"0527f0e3-d92f-453a-8c6d-26bd67d90d77","Code":"INVENTORY","IsActive":true,"Name":"\\u0627\\u0644\\u0645\\u062E\\u0632\\u0648\\u0646","ParentAccountId":null,"Type":0}	System	2026-03-02 01:17:51.909632+00
16479c89-8193-4970-a3b3-6d4335d1ba92	JournalEntryLines	252d6c22-c063-4298-93ba-f06cb4d6f57b	Added	\N	{"Id":"252d6c22-c063-4298-93ba-f06cb4d6f57b","AccountId":"d9f5ba23-6613-4edc-ac98-694c3da99a40","Credit":5000.0,"Debit":0,"Description":"\\u0645\\u0628\\u064A\\u0639\\u0627\\u062A \\u0646\\u0627\\u062A\\u062C\\u0629 \\u0639\\u0646 \\u0641\\u0627\\u062A\\u0648\\u0631\\u0629 INV-20260302011751-8313","JournalEntryId":"b0d2f720-df13-4950-93d1-4fcf86a945be"}	System	2026-03-02 01:17:52.063505+00
730a5349-2f65-4166-80b6-acfec77218d6	JournalEntries	b0d2f720-df13-4950-93d1-4fcf86a945be	Added	\N	{"Id":"b0d2f720-df13-4950-93d1-4fcf86a945be","CreatedBy":"admin","Date":"2026-03-02T01:17:51.9324751Z","Description":"\\u0645\\u0628\\u064A\\u0639\\u0627\\u062A \\u0646\\u0627\\u062A\\u062C\\u0629 \\u0639\\u0646 \\u0641\\u0627\\u062A\\u0648\\u0631\\u0629 INV-20260302011751-8313","IsClosed":false,"Reference":"INV-20260302011751-8313","VoucherNumber":"JV-20260302-7645"}	admin	2026-03-02 01:17:52.067424+00
e0af05d0-dfeb-4992-9db1-91075a3e7846	JournalEntryLines	99e1d96b-a9a4-4cdc-ab22-2008f3fbef63	Added	\N	{"Id":"99e1d96b-a9a4-4cdc-ab22-2008f3fbef63","AccountId":"4f414fcf-737b-4e41-9030-8b5cd9e7cd4a","Credit":0,"Debit":5000.0,"Description":"\\u0645\\u0628\\u064A\\u0639\\u0627\\u062A \\u0646\\u0627\\u062A\\u062C\\u0629 \\u0639\\u0646 \\u0641\\u0627\\u062A\\u0648\\u0631\\u0629 INV-20260302011751-8313","JournalEntryId":"b0d2f720-df13-4950-93d1-4fcf86a945be"}	System	2026-03-02 01:17:52.067394+00
4eb8a317-a15f-41bf-a5bc-8155d1d7ebc5	JournalEntryLines	8aceee7f-6660-4054-956e-e9aa461f0003	Added	\N	{"Id":"8aceee7f-6660-4054-956e-e9aa461f0003","AccountId":"0527f0e3-d92f-453a-8c6d-26bd67d90d77","Credit":17300.00,"Debit":0,"Description":"\\u0625\\u062B\\u0628\\u0627\\u062A \\u062A\\u0643\\u0644\\u0641\\u0629 \\u0627\\u0644\\u0628\\u0636\\u0627\\u0639\\u0629 \\u0627\\u0644\\u0645\\u0628\\u0627\\u0639\\u0629 \\u0644\\u0641\\u0627\\u062A\\u0648\\u0631\\u0629 INV-20260302011751-8313","JournalEntryId":"d58bb39c-ea0c-4d0f-9cdb-71ec8f05f75c"}	System	2026-03-02 01:17:52.163023+00
be03fe52-e97d-4032-a66e-b2eda148cb89	CashTransactions	dd0b882f-2a8b-4581-8c78-4eef2e1c3964	Added	\N	{"Id":"dd0b882f-2a8b-4581-8c78-4eef2e1c3964","Amount":5000.0,"CreatedBy":"admin","Date":"2026-03-02T01:17:52.0897165Z","Description":"\\u0645\\u0628\\u064A\\u0639\\u0627\\u062A \\u0641\\u0627\\u062A\\u0648\\u0631\\u0629 INV-20260302011751-8313 - \\u0645\\u0642\\u062F\\u0645 \\u0642\\u0633\\u0637","JournalEntryId":"b0d2f720-df13-4950-93d1-4fcf86a945be","ReceiptNumber":"INV-20260302011751-8313","TargetAccountId":"d9f5ba23-6613-4edc-ac98-694c3da99a40","Type":0}	admin	2026-03-02 01:17:52.163159+00
\.


--
-- Data for Name: Bundles; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY public."Bundles" ("Id", "Name", "ParentProductId", "SubProductId", "QuantityRequired", "DiscountAmount", "CreatedAt") FROM stdin;
\.


--
-- Data for Name: CashTransactions; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY public."CashTransactions" ("Id", "Date", "ReceiptNumber", "Type", "Amount", "Description", "TargetAccountId", "JournalEntryId", "CreatedBy") FROM stdin;
594a723c-30a4-499f-827a-716db224579a	2026-02-24 21:51:09.365606+00	REC-20260224-425a2902-e2e7-4a20-9d59-b8314765712a	1	1000.00	اجرة عربية من دسوق	4d1ca670-4097-4500-8c1a-3a3d0e1b4489	f2a1a000-d6e5-416e-ab41-0ca1c7e450ed	مدير النظام الأساسي
dd0b882f-2a8b-4581-8c78-4eef2e1c3964	2026-03-02 01:17:52.089716+00	INV-20260302011751-8313	0	5000.00	مبيعات فاتورة INV-20260302011751-8313 - مقدم قسط	d9f5ba23-6613-4edc-ac98-694c3da99a40	b0d2f720-df13-4950-93d1-4fcf86a945be	admin
1ef07da4-799f-4d7b-9488-dbbddac8e2cb	2026-03-04 02:33:00.94854+00	INV-20260304-00001	0	35000.00	مبيعات فاتورة INV-20260304-00001 - مقدم قسط	d9f5ba23-6613-4edc-ac98-694c3da99a40	bc876b68-3043-4939-939b-0610dd177c10	admin
9e3dddc3-eab0-4847-b3ee-8752aef4be4b	2026-03-05 22:18:35.784373+00	INV-20260305-00001	0	5000.00	مقدم أقساط - فاتورة INV-20260305-00001	d9f5ba23-6613-4edc-ac98-694c3da99a40	2846ae56-826d-4dc1-b406-f8004274f996	admin
e6985c23-b03d-420c-92f1-3d6aa7df2ddf	2026-03-08 03:38:47.770227+00	REC-20260308-d72e8a2a-45d5-4e77-8981-615e3a926451	1	500.00	اكراميات \n	4d1ca670-4097-4500-8c1a-3a3d0e1b4489	f6853d11-9d1f-421d-bb29-7ba4f0c3d66a	admin
3998f909-f1e2-406b-8207-e8f35daf1fd2	2026-03-08 03:38:55.696921+00	REC-20260308-e5027c1c-8811-4b93-b573-a671fe356ab4	1	500.00	اكراميات \n	4d1ca670-4097-4500-8c1a-3a3d0e1b4489	a7065875-ead6-40c7-ab9c-b4d6708f3137	admin
d226a633-0923-424f-a349-a65d19b6425d	2026-03-12 02:30:06.373243+00	\N	0	2000.00	سداد من العميل: ريهام  — من اول قسط 	\N	\N	admin
\.


--
-- Data for Name: Customers; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY public."Customers" ("Id", "Name", "Phone", "Address", "Notes", "TotalPurchases", "TotalPaid", "CreatedAt", "IsActive") FROM stdin;
ad9450a9-aec6-4351-9d09-efbc6209dd6e	توكيل تورنيدو 	0124547875	\N	\N	0.00	0.00	2026-02-25 01:09:14.681643+00	f
b44885ed-52ad-44ec-a69b-97af997e8804	توكيل تورنيدو 	0124547875	\N	\N	0.00	0.00	2026-02-25 01:09:16.919159+00	f
dc0051d4-1c72-4d53-8641-1df6701542f7	توكيل تورنيدو 	0124547875	\N	\N	0.00	0.00	2026-02-25 01:09:21.328787+00	f
05bfbfe5-a443-4409-b01b-8b3bccddbe0c	توكيل تورنيدو 	0124547875	\N	\N	0.00	0.00	2026-02-25 01:09:21.711673+00	f
03180482-e110-4001-a542-e64754657098	توكيل تورنيدو 	0124547875	\N	\N	0.00	0.00	2026-02-25 01:09:21.901146+00	f
170d0ccc-f09a-4174-be66-87b00d4b1666	توكيل تورنيدو 	0124547875	\N	\N	0.00	0.00	2026-02-25 01:09:22.093298+00	f
62da2e03-f1b4-42de-897a-618661f00477	توكيل تورنيدو 	0124547875	\N	\N	0.00	0.00	2026-02-25 01:09:21.106183+00	f
ec1dfaca-8583-4695-959a-7b88f7805257	توكيل تورنيدو 	0124547875	\N	\N	0.00	0.00	2026-02-25 01:09:13.795857+00	f
42e849bd-35d2-43d0-9f4b-39aea876d838	توكيل تورنيدو 	0124547875	\N	\N	0.00	0.00	2026-02-25 01:09:13.583083+00	f
bded8c6e-400a-45de-924b-11d152d054c7	توكيل تورنيدو 	0124547875	\N	\N	0.00	0.00	2026-02-25 01:09:21.529758+00	f
72909ad2-dd30-4591-bf6a-f9bb50ad7bef	توكيل تورنيدو 	0124547875	\N	\N	0.00	0.00	2026-02-25 01:09:13.316498+00	f
e4cbac53-802d-4f10-a101-75b6e2f34c34	توكيل تورنيدو 	0124547875	\N	\N	0.00	0.00	2026-02-25 01:09:22.467795+00	f
c99c6edf-a97e-408d-b607-932fa6004ba6	توكيل تورنيدو 	0124547875	\N	\N	0.00	0.00	2026-02-25 01:09:22.283789+00	f
f6ff6cc9-ccdd-4fe5-8977-646fd20e6dca	توكيل تورنيدو 	0124547875	\N	\N	0.00	0.00	2026-02-25 01:09:22.812207+00	f
113c1124-c2c8-4c3b-bd57-63e7255e1d13	توكيل تورنيدو 	0124547875	\N	\N	0.00	0.00	2026-02-25 01:09:22.669597+00	f
d54415d2-3ea2-45dc-bfba-df9527eb0f6e	توكيل تورنيدو 	0124547875	\N	\N	0.00	0.00	2026-02-25 01:09:12.628253+00	f
b55975ac-1769-4720-a059-6cf8e3760a3c	منال	02164574	\N	\N	0.00	0.00	2026-03-04 02:32:02.151357+00	t
23ffdac1-1be6-473a-ae4d-fd795c8e8a64	ريهام 	01154798	\N	\N	11350.00	7000.00	2026-03-02 01:17:08.5476+00	t
\.


--
-- Data for Name: ExpenseCategories; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY public."ExpenseCategories" ("Id", "Name", "IsActive") FROM stdin;
11111111-1111-1111-1111-111111111111	مصروفات تشغيل (كهرباء، غاز، إلخ)	t
22222222-2222-2222-2222-222222222222	رواتب وأجور	t
33333333-3333-3333-3333-333333333333	تسويق وإعلانات	t
44444444-4444-4444-4444-444444444444	أخرى	t
\.


--
-- Data for Name: Expenses; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY public."Expenses" ("Id", "Date", "Amount", "Description", "JournalEntryId", "CreatedBy", "CategoryId", "ReceiptImagePath") FROM stdin;
425a2902-e2e7-4a20-9d59-b8314765712a	2026-02-24 21:51:09.108578+00	1000.00	اجرة عربية من دسوق	f2a1a000-d6e5-416e-ab41-0ca1c7e450ed	مدير النظام الأساسي	44444444-4444-4444-4444-444444444444	\N
d72e8a2a-45d5-4e77-8981-615e3a926451	2026-03-08 03:38:46.496807+00	500.00	اكراميات \n	f6853d11-9d1f-421d-bb29-7ba4f0c3d66a	admin	44444444-4444-4444-4444-444444444444	\N
e5027c1c-8811-4b93-b573-a671fe356ab4	2026-03-08 03:38:55.662503+00	500.00	اكراميات \n	a7065875-ead6-40c7-ab9c-b4d6708f3137	admin	44444444-4444-4444-4444-444444444444	\N
\.


--
-- Data for Name: Installments; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY public."Installments" ("Id", "InvoiceId", "CustomerId", "Amount", "DueDate", "Status", "ReminderSent", "CreatedAt", "PaidAt") FROM stdin;
189e9653-88b9-4f42-8d1e-d9b4ddac21b3	c2fb8408-714f-43dc-a8b3-915008f2d752	23ffdac1-1be6-473a-ae4d-fd795c8e8a64	8441.67	2026-04-03 02:32:32.665616+00	0	f	2026-03-04 02:33:01.300677+00	\N
1b35895c-1c54-4ec4-b2ab-1c39847a1ea2	c2fb8408-714f-43dc-a8b3-915008f2d752	23ffdac1-1be6-473a-ae4d-fd795c8e8a64	8441.67	2026-06-03 01:32:32.665616+00	0	f	2026-03-04 02:33:01.301289+00	\N
1f8e516a-6d11-4963-82a3-7af7818332c0	c2fb8408-714f-43dc-a8b3-915008f2d752	23ffdac1-1be6-473a-ae4d-fd795c8e8a64	8441.65	2026-09-03 01:32:32.665616+00	0	f	2026-03-04 02:33:01.301309+00	\N
67202899-95d7-4c41-ae2a-cdbad970eb1e	c2fb8408-714f-43dc-a8b3-915008f2d752	23ffdac1-1be6-473a-ae4d-fd795c8e8a64	8441.67	2026-08-03 01:32:32.665616+00	0	f	2026-03-04 02:33:01.301302+00	\N
d2ed94ab-c225-4525-a7a1-107b46342042	c2fb8408-714f-43dc-a8b3-915008f2d752	23ffdac1-1be6-473a-ae4d-fd795c8e8a64	8441.67	2026-07-03 01:32:32.665616+00	0	f	2026-03-04 02:33:01.3013+00	\N
e8952d60-0e30-43c5-9ae8-0cab2742e369	c2fb8408-714f-43dc-a8b3-915008f2d752	23ffdac1-1be6-473a-ae4d-fd795c8e8a64	8441.67	2026-05-03 01:32:32.665616+00	0	f	2026-03-04 02:33:01.301103+00	\N
09dff149-1eeb-45a4-8188-8ce511bf834e	12df2e36-e66e-4a8d-bff5-ad445a848cb1	23ffdac1-1be6-473a-ae4d-fd795c8e8a64	1058.33	2026-04-04 22:18:22.899356+00	0	f	2026-03-05 22:18:36.140957+00	\N
1fe644d1-22de-4166-a5cc-06de5cf1a920	12df2e36-e66e-4a8d-bff5-ad445a848cb1	23ffdac1-1be6-473a-ae4d-fd795c8e8a64	1058.35	2026-09-04 21:18:22.899356+00	0	f	2026-03-05 22:18:36.141465+00	\N
34486ddc-15e1-4367-928f-1de2b2fd98af	12df2e36-e66e-4a8d-bff5-ad445a848cb1	23ffdac1-1be6-473a-ae4d-fd795c8e8a64	1058.33	2026-08-04 21:18:22.899356+00	0	f	2026-03-05 22:18:36.14146+00	\N
48cb7f9f-4542-4f7f-84f8-2bcff16d41c3	12df2e36-e66e-4a8d-bff5-ad445a848cb1	23ffdac1-1be6-473a-ae4d-fd795c8e8a64	1058.33	2026-07-04 21:18:22.899356+00	0	f	2026-03-05 22:18:36.141457+00	\N
5bd028d0-ebb3-4f1d-88bd-c122bec83fae	12df2e36-e66e-4a8d-bff5-ad445a848cb1	23ffdac1-1be6-473a-ae4d-fd795c8e8a64	1058.33	2026-06-04 21:18:22.899356+00	0	f	2026-03-05 22:18:36.141453+00	\N
a87505ec-af51-4205-841d-e8eef44a94f3	12df2e36-e66e-4a8d-bff5-ad445a848cb1	23ffdac1-1be6-473a-ae4d-fd795c8e8a64	1058.33	2026-05-04 21:18:22.899356+00	0	f	2026-03-05 22:18:36.141423+00	\N
\.


--
-- Data for Name: InvoiceItems; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY public."InvoiceItems" ("Id", "InvoiceId", "ProductId", "Quantity", "UnitPrice") FROM stdin;
37707145-2df6-4607-a85c-2e4c23f853bf	bbfb9f96-1da2-4b22-ad61-c5fd318c4b31	02654983-613d-47cf-b0d3-e0e5a625d4f4	1	15300.00
009c1a73-c771-461b-9912-05c4c3702b18	e74c65f4-1965-43b3-a02d-7c6e2e0d088f	7194ddb0-6377-4fb6-bf2a-98d68ae6f43a	1	600.00
3c3bf40b-8083-4310-8b10-9312ebd5492a	e74c65f4-1965-43b3-a02d-7c6e2e0d088f	1ffccc5c-1359-4887-b431-23b2f7a0041d	1	4000.00
a6916336-0b13-40e4-9561-92d7fcdffd92	e74c65f4-1965-43b3-a02d-7c6e2e0d088f	02654983-613d-47cf-b0d3-e0e5a625d4f4	1	15300.00
b56e3689-3d25-45e5-a2af-d112b41410ec	e74c65f4-1965-43b3-a02d-7c6e2e0d088f	9a19d885-8f80-4896-bf60-591794dc42ff	1	130.00
46c018f3-97a6-499d-80c8-380988a5172b	5fdb87b5-ad50-4b99-8429-01203f5b9be1	9a19d885-8f80-4896-bf60-591794dc42ff	1	130.00
46c0b254-afd5-4c11-bcfe-d00022840a75	5fdb87b5-ad50-4b99-8429-01203f5b9be1	1ffccc5c-1359-4887-b431-23b2f7a0041d	1	4000.00
590fb632-e66c-4e1f-877a-dcb26b506c24	5fdb87b5-ad50-4b99-8429-01203f5b9be1	02654983-613d-47cf-b0d3-e0e5a625d4f4	1	15300.00
d35d2fb7-17bd-4f29-94fc-e3646a013a66	5fdb87b5-ad50-4b99-8429-01203f5b9be1	7194ddb0-6377-4fb6-bf2a-98d68ae6f43a	1	600.00
66642719-60d7-4a47-847b-b9fda7e92f62	4fa6c4c1-ee47-48d2-a62c-9f1006e61b22	1ffccc5c-1359-4887-b431-23b2f7a0041d	1	4000.00
b5814aca-6342-4ddd-9370-d687a16ad1a2	4fa6c4c1-ee47-48d2-a62c-9f1006e61b22	02654983-613d-47cf-b0d3-e0e5a625d4f4	1	15300.00
06368db0-17da-44e4-9c21-86654490f38f	c2fb8408-714f-43dc-a8b3-915008f2d752	b7158a95-eafa-49cc-9510-42ba70e8d2b7	1	11500.00
086eadcb-2336-4973-a147-3cda99d77c5f	c2fb8408-714f-43dc-a8b3-915008f2d752	90706a3a-181e-46c5-8aee-4eef92e3d651	1	1500.00
3f232363-ab86-44c5-ba21-7dbe88134b79	c2fb8408-714f-43dc-a8b3-915008f2d752	6e658f48-e69a-434e-a00a-dfda36e45937	1	8900.00
58c15efa-502c-4349-a1a8-f99e9b72cb7b	c2fb8408-714f-43dc-a8b3-915008f2d752	18ba4f41-d2df-4467-9c4a-54eb264b75e8	1	17000.00
5ccf3859-25f4-4828-9bfa-df434dba8cf7	c2fb8408-714f-43dc-a8b3-915008f2d752	b3b0e974-e2cf-4ca2-b954-a82be22aca50	1	8500.00
97f6715d-91c2-4529-8d00-458994bb4fb4	c2fb8408-714f-43dc-a8b3-915008f2d752	28ccb74a-07d0-4860-bbf0-9a055657f410	1	3100.00
c9a0628b-f7de-4d12-90f5-6a2ceff8b2ce	c2fb8408-714f-43dc-a8b3-915008f2d752	4df65b55-bd74-4757-92d2-e456c8551ab3	1	3900.00
cd05bf6d-0f46-4ba7-9f2e-80b88253198c	c2fb8408-714f-43dc-a8b3-915008f2d752	6e409bf9-3d54-4c49-a11c-0c31bb185324	1	2300.00
f3b80b17-b2da-4e1c-b99b-11eac92cf41f	c2fb8408-714f-43dc-a8b3-915008f2d752	266bcbe5-4bb5-4e86-b5e6-0c72bf32a280	1	28000.00
fe89d172-27f1-47ef-a395-b4a1b8cf4e55	c2fb8408-714f-43dc-a8b3-915008f2d752	c1db1d0e-d3c1-4488-8a06-1c82ed21264e	1	950.00
18683d94-b7e8-4ed5-8328-7d295c22c03d	12df2e36-e66e-4a8d-bff5-ad445a848cb1	90706a3a-181e-46c5-8aee-4eef92e3d651	1	1500.00
7942b4d9-784c-4df7-a377-2106da83d555	12df2e36-e66e-4a8d-bff5-ad445a848cb1	6e658f48-e69a-434e-a00a-dfda36e45937	1	8900.00
c09807c2-f3fc-4bcc-a568-79ebd412da03	12df2e36-e66e-4a8d-bff5-ad445a848cb1	c1db1d0e-d3c1-4488-8a06-1c82ed21264e	1	950.00
\.


--
-- Data for Name: Invoices; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY public."Invoices" ("Id", "InvoiceNo", "CustomerId", "TotalAmount", "DiscountAmount", "PaymentType", "Status", "Notes", "CreatedAt", "CreatedBy", "CashierId", "PaidAmount", "RemainingAmount", "SubTotal", "VatAmount", "VatRate", "PaymentReference", "EventDate", "DeliveryDate", "IsBridal", "BridalNotes", "InstallmentCount", "InstallmentPeriod", "InterestRate") FROM stdin;
bbfb9f96-1da2-4b22-ad61-c5fd318c4b31	INV-20260301003614-3527	\N	15300.00	0.00	0	0	\N	2026-03-01 00:36:14.705939+00	admin	435668be-b38c-417d-979a-7ac88b8b4174	15300.00	0.00	15300.00	0.00	0.00	\N	\N	\N	f	\N	0	0	0.0
e74c65f4-1965-43b3-a02d-7c6e2e0d088f	INV-20260301010714-7302	\N	20030.00	0.00	0	0	\N	2026-03-01 01:07:14.55384+00	admin	435668be-b38c-417d-979a-7ac88b8b4174	20030.00	0.00	20030.00	0.00	0.00	\N	\N	\N	f	\N	0	0	0.0
5fdb87b5-ad50-4b99-8429-01203f5b9be1	INV-20260301012209-8431	\N	20030.00	0.00	2	0	\N	2026-03-01 01:22:09.571076+00	admin	435668be-b38c-417d-979a-7ac88b8b4174	0.00	20030.00	20030.00	0.00	0.00	\N	\N	\N	f	\N	0	0	0.0
4fa6c4c1-ee47-48d2-a62c-9f1006e61b22	INV-20260302011751-8313	\N	19300.00	0.00	2	0	\N	2026-03-02 01:17:51.318838+00	admin	435668be-b38c-417d-979a-7ac88b8b4174	5000.00	14300.00	19300.00	0.00	0.00	\N	\N	\N	f	\N	0	0	0.0
c2fb8408-714f-43dc-a8b3-915008f2d752	INV-20260304-00001	23ffdac1-1be6-473a-ae4d-fd795c8e8a64	85650.00	0.00	2	0	\N	2026-03-04 02:33:00.00486+00	admin	435668be-b38c-417d-979a-7ac88b8b4174	35000.00	50650.00	85650.00	0.00	0.00	\N	\N	\N	f	\N	0	0	0.0
12df2e36-e66e-4a8d-bff5-ad445a848cb1	INV-20260305-00001	23ffdac1-1be6-473a-ae4d-fd795c8e8a64	11350.00	0.00	2	0	\N	2026-03-05 22:18:35.085024+00	admin	435668be-b38c-417d-979a-7ac88b8b4174	5000.00	6350.00	11350.00	0.00	0.00	\N	\N	\N	f	\N	0	0	0.0
\.


--
-- Data for Name: JournalEntries; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY public."JournalEntries" ("Id", "VoucherNumber", "Date", "Reference", "Description", "CreatedBy", "IsClosed") FROM stdin;
f2a1a000-d6e5-416e-ab41-0ca1c7e450ed	JV-20260224-6836	2026-02-24 21:51:09.212666+00	EXP-20260224-425a2902-e2e7-4a20-9d59-b8314765712a	اجرة عربية من دسوق	مدير النظام الأساسي	f
b0d2f720-df13-4950-93d1-4fcf86a945be	JV-20260302-7645	2026-03-02 01:17:51.932475+00	INV-20260302011751-8313	مبيعات ناتجة عن فاتورة INV-20260302011751-8313	admin	f
d58bb39c-ea0c-4d0f-9cdb-71ec8f05f75c	JV-20260302-5980	2026-03-02 01:17:52.149092+00	INV-20260302011751-8313	إثبات تكلفة البضاعة المباعة لفاتورة INV-20260302011751-8313	admin	f
bc876b68-3043-4939-939b-0610dd177c10	JV-20260304-5035	2026-03-04 02:33:00.814359+00	INV-20260304-00001	مبيعات ناتجة عن فاتورة INV-20260304-00001	admin	f
55957304-1841-469e-9640-1846bd5af07f	JV-20260304-7825	2026-03-04 02:33:01.012361+00	INV-20260304-00001	إثبات تكلفة البضاعة المباعة لفاتورة INV-20260304-00001	admin	f
2846ae56-826d-4dc1-b406-f8004274f996	JV-20260305-2350	2026-03-05 22:18:35.682117+00	INV-20260305-00001	مبيعات بالتقسيط - فاتورة INV-20260305-00001	admin	f
8ff1a7b0-e54d-4377-8975-d6b2bfb8d22b	JV-20260305-7196	2026-03-05 22:18:35.836979+00	INV-20260305-00001	إثبات تكلفة البضاعة المباعة لفاتورة INV-20260305-00001	admin	f
f6853d11-9d1f-421d-bb29-7ba4f0c3d66a	JV-20260308-9843	2026-03-08 03:38:46.730804+00	EXP-20260308-d72e8a2a-45d5-4e77-8981-615e3a926451	اكراميات \n	admin	f
a7065875-ead6-40c7-ab9c-b4d6708f3137	JV-20260308-5884	2026-03-08 03:38:55.679474+00	EXP-20260308-e5027c1c-8811-4b93-b573-a671fe356ab4	اكراميات \n	admin	f
\.


--
-- Data for Name: JournalEntryLines; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY public."JournalEntryLines" ("Id", "JournalEntryId", "AccountId", "Description", "Debit", "Credit") FROM stdin;
5409f471-c68f-4643-8117-589b1ba487c8	f2a1a000-d6e5-416e-ab41-0ca1c7e450ed	4f414fcf-737b-4e41-9030-8b5cd9e7cd4a	اجرة عربية من دسوق	0.00	1000.00
7bf233e9-b03a-4ac8-90bc-f6a82b9c1a64	f2a1a000-d6e5-416e-ab41-0ca1c7e450ed	4d1ca670-4097-4500-8c1a-3a3d0e1b4489	اجرة عربية من دسوق	1000.00	0.00
252d6c22-c063-4298-93ba-f06cb4d6f57b	b0d2f720-df13-4950-93d1-4fcf86a945be	d9f5ba23-6613-4edc-ac98-694c3da99a40	مبيعات ناتجة عن فاتورة INV-20260302011751-8313	0.00	5000.00
99e1d96b-a9a4-4cdc-ab22-2008f3fbef63	b0d2f720-df13-4950-93d1-4fcf86a945be	4f414fcf-737b-4e41-9030-8b5cd9e7cd4a	مبيعات ناتجة عن فاتورة INV-20260302011751-8313	5000.00	0.00
885e5c8d-27d8-4fe9-b947-c9c1659f74a3	d58bb39c-ea0c-4d0f-9cdb-71ec8f05f75c	9444dd9c-ee49-4b76-a202-106fd5c82382	إثبات تكلفة البضاعة المباعة لفاتورة INV-20260302011751-8313	17300.00	0.00
8aceee7f-6660-4054-956e-e9aa461f0003	d58bb39c-ea0c-4d0f-9cdb-71ec8f05f75c	0527f0e3-d92f-453a-8c6d-26bd67d90d77	إثبات تكلفة البضاعة المباعة لفاتورة INV-20260302011751-8313	0.00	17300.00
169c1c5c-9cef-48d7-9a71-5679bee891bc	bc876b68-3043-4939-939b-0610dd177c10	d9f5ba23-6613-4edc-ac98-694c3da99a40	مبيعات ناتجة عن فاتورة INV-20260304-00001	0.00	35000.00
3f49e3bb-a7cd-4267-b230-7cf98f92b221	bc876b68-3043-4939-939b-0610dd177c10	4f414fcf-737b-4e41-9030-8b5cd9e7cd4a	مبيعات ناتجة عن فاتورة INV-20260304-00001	35000.00	0.00
92520003-3170-4bed-a471-1ff131d8e7a3	55957304-1841-469e-9640-1846bd5af07f	0527f0e3-d92f-453a-8c6d-26bd67d90d77	إثبات تكلفة البضاعة المباعة لفاتورة INV-20260304-00001	0.00	68520.00
e692c06c-0449-4e4a-8a0b-b90839cb67fb	55957304-1841-469e-9640-1846bd5af07f	9444dd9c-ee49-4b76-a202-106fd5c82382	إثبات تكلفة البضاعة المباعة لفاتورة INV-20260304-00001	68520.00	0.00
5e2540f5-d70e-4e2e-b888-10b1a739e3e1	2846ae56-826d-4dc1-b406-f8004274f996	18b0eefe-8b44-46d8-a973-5f8c18f16261	مبيعات بالتقسيط - فاتورة INV-20260305-00001	6350.00	0.00
c0c780d9-c322-46c0-9931-b60e5ef808f9	2846ae56-826d-4dc1-b406-f8004274f996	d9f5ba23-6613-4edc-ac98-694c3da99a40	مبيعات بالتقسيط - فاتورة INV-20260305-00001	0.00	11350.00
e50fd380-64f5-460d-a270-a0474ccfc64d	2846ae56-826d-4dc1-b406-f8004274f996	4f414fcf-737b-4e41-9030-8b5cd9e7cd4a	مبيعات بالتقسيط - فاتورة INV-20260305-00001	5000.00	0.00
44d19c94-2f4a-4ec6-b91d-9f8c24ba91c1	8ff1a7b0-e54d-4377-8975-d6b2bfb8d22b	9444dd9c-ee49-4b76-a202-106fd5c82382	إثبات تكلفة البضاعة المباعة لفاتورة INV-20260305-00001	9080.00	0.00
c1671365-7a69-4832-baa0-a1ae79a65ff2	8ff1a7b0-e54d-4377-8975-d6b2bfb8d22b	0527f0e3-d92f-453a-8c6d-26bd67d90d77	إثبات تكلفة البضاعة المباعة لفاتورة INV-20260305-00001	0.00	9080.00
347927c8-d744-4efb-87f3-a6d0100117ae	f6853d11-9d1f-421d-bb29-7ba4f0c3d66a	4f414fcf-737b-4e41-9030-8b5cd9e7cd4a	اكراميات \n	0.00	500.00
ec5f2b91-650e-49e8-99b0-48e73c27159e	f6853d11-9d1f-421d-bb29-7ba4f0c3d66a	4d1ca670-4097-4500-8c1a-3a3d0e1b4489	اكراميات \n	500.00	0.00
14a5e311-b7b4-4b58-84f1-24e6b5e0ff04	a7065875-ead6-40c7-ab9c-b4d6708f3137	4d1ca670-4097-4500-8c1a-3a3d0e1b4489	اكراميات \n	500.00	0.00
2b766e29-ef7a-4f60-9ff4-2b5ed15c726c	a7065875-ead6-40c7-ab9c-b4d6708f3137	4f414fcf-737b-4e41-9030-8b5cd9e7cd4a	اكراميات \n	0.00	500.00
\.


--
-- Data for Name: ProductUnits; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY public."ProductUnits" ("Id", "ProductId", "UnitType", "ConversionFactor", "UnitPrice", "UnitBarcode") FROM stdin;
\.


--
-- Data for Name: Products; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY public."Products" ("Id", "Name", "GlobalBarcode", "InternalBarcode", "Description", "PurchasePrice", "WholesalePrice", "Price", "StockQuantity", "MinStockAlert", "ExpiryDate", "Category", "CreatedAt", "UpdatedAt", "ImageUrl", "IsActive") FROM stdin;
10025863-e648-4e3f-8d70-394e8d69d202	شاشة تورنيدو 32	2001867464	2001867464	\N	4000.00	4000.00	4500.00	10	5	\N	اجهزة كهربائية	2026-02-24 21:39:42.310229+00	\N	\N	f
de33fb08-54c9-4ef2-ad81-e33b1f6c9873	بتوجاز ايديال 	200-2026-00003	200-2026-00003	\N	14300.00	14300.00	15300.00	20	5	\N	اجهزة كهربائية	2026-02-25 23:55:05.146679+00	\N	\N	f
e438bb3f-925c-4533-9e0e-fa96051f4372	خلاط مولينكس 500 وات	850007	PROD5007	\N	960.00	1080.00	1200.00	50	5	\N	أجهزة صغيرة	2026-03-04 00:14:43.653006+00	2026-03-04 00:14:43.653006+00	/uploads/products/blender.jpg	f
18ba4f41-d2df-4467-9c4a-54eb264b75e8	تكييف تورنيدو 1.5 حصان سبليت	850005	PROD5005	\N	13600.00	15300.00	17000.00	49	5	\N	أجهزة منزلية	2026-03-04 00:14:43.653006+00	2026-03-04 00:14:43.653006+00	/uploads/products/ac.jpg	t
266bcbe5-4bb5-4e86-b5e6-0c72bf32a280	ثلاجة شارب ديجيتال 18 قدم	850002	PROD5002	\N	22400.00	25200.00	28000.00	49	5	\N	أجهزة منزلية	2026-03-04 00:14:43.653006+00	2026-03-04 00:14:43.653006+00	/uploads/products/fridge.jpg	t
4df65b55-bd74-4757-92d2-e456c8551ab3	سخان مياه غاز تورنيدو 10 لتر	850010	PROD5010	\N	3120.00	3510.00	3900.00	49	5	\N	أجهزة منزلية	2026-03-04 00:14:43.653006+00	2026-03-04 00:14:43.653006+00	/uploads/products/heater.jpg	t
6e409bf9-3d54-4c49-a11c-0c31bb185324	مكواة بخار تيفال 2000 وات	850009	PROD5009	\N	1840.00	2070.00	2300.00	49	5	\N	أجهزة صغيرة	2026-03-04 00:14:43.653006+00	2026-03-04 00:14:43.653006+00	/uploads/products/iron.jpg	t
b3b0e974-e2cf-4ca2-b954-a82be22aca50	بوتاجاز يونيفرسال 5 شعلة	850004	PROD5004	\N	6800.00	7650.00	8500.00	49	5	\N	أجهزة منزلية	2026-03-04 00:14:43.653006+00	2026-03-04 00:14:43.653006+00	/uploads/products/stove.jpg	t
b7158a95-eafa-49cc-9510-42ba70e8d2b7	شاشة سامسونج سمارت 50 بوصة	850001	PROD5001	\N	9200.00	10350.00	11500.00	49	5	\N	أجهزة منزلية	2026-03-04 00:14:43.653006+00	2026-03-04 00:14:43.653006+00	/uploads/products/tv.png	t
7194ddb0-6377-4fb6-bf2a-98d68ae6f43a	كاتل 	\N	200-2026-00003	\N	500.00	500.00	600.00	28	0	\N	اجهزة كهربائية	2026-02-26 00:46:40.814368+00	2026-02-26 00:54:38.747325+00	\N	t
9a19d885-8f80-4896-bf60-591794dc42ff	سلة غسيل 	\N	200-2026-00004	\N	100.00	100.00	130.00	48	5	\N	بلاستيك	2026-02-26 01:02:59.960322+00	\N	\N	t
02654983-613d-47cf-b0d3-e0e5a625d4f4	بتوجاز ايديال 	200-2026-00002	200-2026-00002	\N	14300.00	14300.00	15300.00	16	5	\N	اجهزة كهربائية	2026-02-25 23:54:58.160073+00	\N	\N	t
1ffccc5c-1359-4887-b431-23b2f7a0041d	شاشة تورنيدو 	200-2026-00001	200-2026-00001	\N	3000.00	3000.00	4000.00	17	5	\N	اجهزة كهربائية	2026-02-25 23:53:29.804571+00	\N	\N	t
6bff4c35-8695-4c85-aee8-fe9c7e643dc0	شاشة سامسونج 43 بوصة	\N	200-2026-00005	\N	10000.00	10000.00	11000.00	20	0	\N	\N	2026-03-03 22:13:31.011994+00	\N	\N	t
c43c1254-c890-4596-b089-1d3a9de96ebd	غسالة توشيبا فوق اوتوماتيك 10 كيلو	850003	PROD5003	\N	11600.00	13050.00	14500.00	50	5	\N	أجهزة منزلية	2026-03-04 00:14:43.653006+00	2026-03-04 00:14:43.653006+00	/uploads/products/washer.jpg	t
bf7cb084-d050-41a1-a985-88a2af0bf503	ميكروويف فريش 28 لتر	850006	PROD5006	\N	3360.00	3780.00	4200.00	50	5	\N	أجهزة منزلية	2026-03-04 00:14:43.653006+00	2026-03-04 00:14:43.653006+00	/uploads/products/microwave.jpg	t
7d38e575-324a-4c3f-a79d-1f1a2e64489b	مروحة ستاند فريش 16 بوصة	850008	PROD5008	\N	1440.00	1620.00	1800.00	50	5	\N	أجهزة منزلية	2026-03-04 00:14:43.653006+00	2026-03-04 00:14:43.653006+00	/uploads/products/fan.jpg	t
17f9af0f-688f-4fd9-9189-ea3fcf787ba6	مكنسة كهربائية باناسونيك 2000 وات	850011	PROD5011	\N	4400.00	4950.00	5500.00	50	5	\N	أجهزة منزلية	2026-03-04 00:14:43.653006+00	2026-03-04 00:14:43.653006+00	/uploads/products/vacuum.jpg	t
011628dd-6717-4b3e-80c3-e287aaf61c9d	مبرد مياه كولدير بحافظة	850014	PROD5014	\N	3680.00	4140.00	4600.00	50	5	\N	أجهزة منزلية	2026-03-04 00:14:43.653006+00	2026-03-04 00:14:43.653006+00	/uploads/products/cooler.jpg	t
7ee1a1c4-e7b5-4e48-83e6-2ae6065632e5	دفاية زيت ديلونجي 9 ريشة	850015	PROD5015	\N	4960.00	5580.00	6200.00	50	5	\N	أجهزة منزلية	2026-03-04 00:14:43.653006+00	2026-03-04 00:14:43.653006+00	/uploads/products/oil_heater.jpg	t
43e675fd-ef02-4edb-aa0f-4d757b1dca72	غسالة اطباق بيكو 14 فرد	850020	PROD5020	\N	15600.00	17550.00	19500.00	50	5	\N	أجهزة منزلية	2026-03-04 00:14:43.653006+00	2026-03-04 00:14:43.653006+00	/uploads/products/dishwasher.jpg	t
825c0802-5a04-436a-9e15-26fa144e5a36	صانعة قهوة ديلونجي اسبريسو	850018	PROD5018	\N	6000.00	6750.00	7500.00	50	5	\N	أجهزة صغيرة	2026-03-04 00:14:43.653006+00	2026-03-04 00:14:43.653006+00	/uploads/products/coffee.jpg	f
795a986a-84a7-4567-be18-57b173d76d30	عجانة كينوود 1000 وات	850019	PROD5019	\N	10000.00	11250.00	12500.00	50	5	\N	أجهزة صغيرة	2026-03-04 00:14:43.653006+00	2026-03-04 00:14:43.653006+00	/uploads/products/mixer.jpg	f
28ccb74a-07d0-4860-bbf0-9a055657f410	محضر طعام (كبة) براون 600 وات	850012	PROD5012	\N	2480.00	2790.00	3100.00	49	5	\N	أجهزة صغيرة	2026-03-04 00:14:43.653006+00	2026-03-04 00:14:43.653006+00	/uploads/products/processor.jpg	t
6e658f48-e69a-434e-a00a-dfda36e45937	قلاية بدون زيت (ايرفراير) فيليبس	850016	PROD5016	\N	7120.00	8010.00	8900.00	48	5	\N	أجهزة صغيرة	2026-03-04 00:14:43.653006+00	2026-03-04 00:14:43.653006+00	/uploads/products/fryer.jpg	t
90706a3a-181e-46c5-8aee-4eef92e3d651	ماكينة حلاقة براون للرجال	850017	PROD5017	\N	1200.00	1350.00	1500.00	48	5	\N	أجهزة صغيرة	2026-03-04 00:14:43.653006+00	2026-03-04 00:14:43.653006+00	/uploads/products/shaver.jpg	t
c1db1d0e-d3c1-4488-8a06-1c82ed21264e	كاتل (غلاية مياه) كينوود سعة 1.7 لتر	850013	PROD5013	\N	760.00	855.00	950.00	48	5	\N	أجهزة صغيرة	2026-03-04 00:14:43.653006+00	2026-03-04 00:14:43.653006+00	/uploads/products/kettle.jpg	t
\.


--
-- Data for Name: PurchaseInvoiceItems; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY public."PurchaseInvoiceItems" ("Id", "PurchaseInvoiceId", "ProductId", "Quantity", "UnitPrice", "TotalPrice") FROM stdin;
30e61b48-b9d4-4c35-98ad-b9182b1f14b2	895a892e-d764-479b-b74b-1d8b75baaae1	7194ddb0-6377-4fb6-bf2a-98d68ae6f43a	5.0	550.00	2750.00
d49c532e-4c79-48b7-bba9-10cb7edec019	895a892e-d764-479b-b74b-1d8b75baaae1	1ffccc5c-1359-4887-b431-23b2f7a0041d	5.0	33100.00	165500.00
\.


--
-- Data for Name: PurchaseInvoices; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY public."PurchaseInvoices" ("Id", "InvoiceNo", "Date", "SupplierId", "TotalAmount", "Discount", "NetAmount", "PaidAmount", "RemainingAmount", "JournalEntryId", "CreatedBy", "CreatedAt", "Notes", "Status") FROM stdin;
895a892e-d764-479b-b74b-1d8b75baaae1	\N	2026-03-01 00:35:30.094648+00	d4c917f8-755b-464a-8a2a-3df3a5c14b05	168250.00	0.00	168250.00	0.00	168250.00	\N	admin	2026-03-01 00:35:30.094651+00	\N	0
\.


--
-- Data for Name: RefreshTokens; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY public."RefreshTokens" ("Id", "Token", "Expires", "Created", "Revoked", "UserId") FROM stdin;
1c86c4bd-0439-4184-b8b0-5e391f04c878	gDG6+BUUi2wZ8jmdo+L3/5trCks4bAofgiu2ODZiP0ICF2GDXOsrLOEdmHFuO7KaPzcK61IsflMBZPZZNITqJg==	2026-03-04 01:14:17.397279+00	2026-02-25 01:14:17.397242+00	\N	435668be-b38c-417d-979a-7ac88b8b4174
58c9f5d7-6fc6-4496-816f-1d3800f40295	d6fA+JH60gid+a/Yu6v4fqrOrW8GoQI4G1AzQ6XlGb3RAmnefxg1YGoVUkYyK+tio144tA3OwlsvtdhuJAXuig==	2026-03-04 01:14:26.477391+00	2026-02-25 01:14:26.477391+00	\N	435668be-b38c-417d-979a-7ac88b8b4174
552faaf8-435e-4ff5-919c-5b16b2767525	/q3ZQzEC8tNJpWFTUI8SuGbCaVZxIf3c1JxuG493h/ma1427NqXBDBuUbNXqYjuRuGWQDQDeONMmeK2KYWydow==	2026-03-04 01:25:34.895545+00	2026-02-25 01:25:34.89538+00	2026-02-25 23:21:28.997133+00	435668be-b38c-417d-979a-7ac88b8b4174
bc132b1d-da68-403a-ad6c-2b25880d338d	jlQ8IqHkFZgPrkeciJeT+4SI1aE6LJn1N7OxKgq1a/kRlaaDmvys2k1zBvrHsLS/RTRwWH3jIY1kAEFS4D0P4Q==	2026-03-04 23:21:29.034471+00	2026-02-25 23:21:29.034469+00	\N	435668be-b38c-417d-979a-7ac88b8b4174
46f79f3d-2ab9-40ad-bb7a-9ee20499ea9b	iA918NWTVRG47uUhnx4uGeYTwpyBY0Z6r0lkq6RSyWV/NG9BqdMidzCXVUBjCm7SqVp7Q0QoCJ8Yjr9y0WrUKg==	2026-03-04 23:21:29.032656+00	2026-02-25 23:21:29.032565+00	2026-02-25 23:52:53.768607+00	435668be-b38c-417d-979a-7ac88b8b4174
ca965382-1703-4c42-9faa-e902691964d3	ffUF8sm+uawP0iy+rx0lasax0dQJ5vQUAMDufnT+Q47rmKKPlgdf4ev40EeXrdU0bvhm3sfxND1ocQyy2aH7Dw==	2026-03-07 23:01:58.485011+00	2026-02-28 23:01:58.484962+00	\N	435668be-b38c-417d-979a-7ac88b8b4174
289dab17-a72c-4b3d-a717-de6c889fa392	XoNaTjacw0v8OEHi+5F37xAdpvmHDMdDzMXMAJ78HB/kFWJ99/WZmCMbfeagP/w0fTeH0/GPUKq9Pmd6re1U1w==	2026-03-05 00:25:56.002673+00	2026-02-26 00:25:56.002576+00	\N	435668be-b38c-417d-979a-7ac88b8b4174
4963c7ee-db8f-4d47-9c8a-d447bf98481d	NEOyXjF239TqTiQqDbvtTiFPkQuRFhfuDEjPnVJSzz8Vsi3lMFXTAbWN0wu8unURmH9F25I/yYvk1BjUml/ccw==	2026-03-04 23:52:53.769131+00	2026-02-25 23:52:53.76913+00	2026-02-26 00:25:55.969606+00	435668be-b38c-417d-979a-7ac88b8b4174
d177e207-19b6-4882-9fa5-7d72208e3676	BnYWsa7Nw2QaZ4XaYQ9+tFLO7xQFoHFS9quwqv+TzBKbhrccPZS2kWM6F2RVwor5bWSzmsSTEHkFB2L5uVr02w==	2026-03-05 00:25:56.002677+00	2026-02-26 00:25:56.002576+00	2026-02-26 00:59:15.907619+00	435668be-b38c-417d-979a-7ac88b8b4174
05e48349-cf3d-43c8-b7ee-1e6dcd996aeb	wKTTSBOsc5oeyjQEqJaufNBNZ0o207dRfFLyQf0Irhs2z/jqfx7YcdDL5+ldJjGFGaKjSIOP8bCRa1xYcod9BA==	2026-03-10 22:26:21.501076+00	2026-03-03 22:26:21.500983+00	2026-03-03 22:59:00.852232+00	435668be-b38c-417d-979a-7ac88b8b4174
6f135bc2-2e2e-4063-baf7-e1973ddb8f5b	Ybw2iL8OAjUq8A1j8VrlT1kbO0B1HJrX9yHtrhyOwpjg0zKlbviJNK5ZAt3P00q/sv37gqIwRVo6oSvi+1rjeA==	2026-03-05 01:48:30.048393+00	2026-02-26 01:48:30.048337+00	\N	435668be-b38c-417d-979a-7ac88b8b4174
3f08af72-9dad-4eec-bcc2-193b7fea912d	xJ4rEYSGo/HmLe0Gl6TYE2QsMa0VWH0ghb3g/7FkDI6AwxEV/4+90E96xmewk/4zoV2hE1YuKjtRjA8xe+0Zhw==	2026-03-05 00:59:15.926243+00	2026-02-26 00:59:15.926177+00	2026-02-26 01:48:30.024181+00	435668be-b38c-417d-979a-7ac88b8b4174
fc407c3c-260f-43a7-84c3-8137df39c5b3	E7koWCrt9B6OUpZu7/X+mv/qGsS5p0tRaXwe8IT+zXo5M/tpSxuY9KR6fanyAIQkkOMkNkBnRxbG7UtEuelGQw==	2026-03-05 02:19:35.056347+00	2026-02-26 02:19:35.056347+00	\N	435668be-b38c-417d-979a-7ac88b8b4174
f1099a80-d49c-4923-b4e3-f6d3c6cbc2cd	ZTwrNTnrOoGRPrXU2bhZnC5O9GEfctJxVUIud8kcgmq4+3dEdmxCqPwt0o/XMN6+2ausRj4Nb2A5wy7K6PO4sA==	2026-03-05 01:48:30.048401+00	2026-02-26 01:48:30.04834+00	2026-02-26 02:19:35.055226+00	435668be-b38c-417d-979a-7ac88b8b4174
c77da1b1-1ea0-41d4-98aa-1589958f6bbf	0LPyo/ZPopJx+a3+siyH7UjWbE2+dW0jyoT4oVxEGI0FNjeJkii21D+kBdBBtVJ2GKaVaAI5IbrWVBjIan+RcQ==	2026-03-07 22:40:04.199562+00	2026-02-28 22:40:04.19956+00	2026-03-01 00:26:39.974308+00	435668be-b38c-417d-979a-7ac88b8b4174
15804d93-7468-49f4-821f-bc16d52a2dab	Zxr8uhNcB1RR7qkVvlg7xB1b9fqP8aKz+wS7xE4Melff6yBslp/3yLBXs6ySEoOJu0v4ysT1f03gjgF9jXI3Lg==	2026-03-05 23:56:13.054412+00	2026-02-26 23:56:13.0543+00	\N	435668be-b38c-417d-979a-7ac88b8b4174
e48492bc-e509-41b1-b220-bc50c079903a	vs0Nwrz0phWDDsorSwEAkY6VXCf7SQOIEq1ZjicMpIlxgNPl1/gUZpoj6JBX/+VoevaRmS6tvXuRQecS07qB6A==	2026-03-05 02:19:35.056317+00	2026-02-26 02:19:35.056317+00	2026-02-26 23:56:13.028915+00	435668be-b38c-417d-979a-7ac88b8b4174
40da819e-f525-4cd8-84d0-dac277478a85	Y5fme5nu4orh6jXn03qMorjevN+roF7YQETy2ZoXbHN8LpDrYTH/LWEsjBHkw5spUSQgnopknxpe3zr8IkuPlg==	2026-03-08 00:26:39.974719+00	2026-03-01 00:26:39.974717+00	\N	435668be-b38c-417d-979a-7ac88b8b4174
6550e7e3-3af7-43f0-8402-ae94cf2021d4	xIYEN6FRzYsIo/+BZSchFmLjqaxJaFr62vukWxYFtr7UwxXXeAXLvQWr7qzwhlhhV6dxM3ILpqL0MybWC57A1g==	2026-03-06 00:27:06.099211+00	2026-02-27 00:27:06.099211+00	\N	435668be-b38c-417d-979a-7ac88b8b4174
44ad91db-51fa-4b4b-a6ac-52983b5c00a1	IHKyj3i9zg9xlVRu45ZWaIfmK2r65car0PgMmCAvi9ya9nq+DVatt5yKwyCbueuLroJ4KQgUrZFAYbtWQDO3Kw==	2026-03-09 03:00:54.263103+00	2026-03-02 03:00:54.263038+00	\N	435668be-b38c-417d-979a-7ac88b8b4174
17e71313-fddc-468d-abe5-bd743a2f5604	rrcNCwe2bLju2GPvtVhv6Njgy1BGRy14+/yaNJx/1aKjtifzqrvbt8npXPK7onsgcHGzJVac07arph3KxcvwGA==	2026-03-06 00:27:06.099547+00	2026-02-27 00:27:06.099547+00	\N	435668be-b38c-417d-979a-7ac88b8b4174
50f5f35a-64b9-4c22-8c81-add41b40834d	a2t0H4E0wSob9a0eQp7sm66vyYC3K5w0Xej6YjC4NXcpQ/GaPk20KR5RvGbWtugqNz/2FOKTo6cAOJ3nmU6IUg==	2026-03-05 23:56:13.054404+00	2026-02-26 23:56:13.054299+00	2026-02-27 00:27:06.100646+00	435668be-b38c-417d-979a-7ac88b8b4174
2e33fc5e-37b5-49a4-9dce-054af42ea354	8iE2EJFKIPclrqLVaAqyzNHH0zEislnHhOtEnxpFBaQXlYFx2GqS+/bKbsa3+A01Z3SKKuqsYiKGq4fECl0ucA==	2026-03-06 01:11:23.995193+00	2026-02-27 01:11:23.995192+00	\N	435668be-b38c-417d-979a-7ac88b8b4174
0d2fa023-cc68-4c17-a76a-ee680cc747d5	xFyHOWjiLJb+iA62XENS4PoF7ufVcGnrFscCBtxydHTz44x/GiTyaPLZbjDIMqUMkkkC9116eDnF+TqxDtZ0Kw==	2026-03-08 01:06:38.573607+00	2026-03-01 01:06:38.573604+00	\N	435668be-b38c-417d-979a-7ac88b8b4174
3692bd97-3933-44f6-bfbd-77140caf473b	yjyHRMCWpSz+jPmtW7xJJAL2u6GmfdGcyxsOUQKXwkOJMABEN0cAjs1d6tzdYSdtp6WAKrnRzEMdXNNWEejaaA==	2026-03-06 00:27:06.101244+00	2026-02-27 00:27:06.101244+00	2026-02-28 21:27:46.519704+00	435668be-b38c-417d-979a-7ac88b8b4174
2ab1831d-b4fe-4b4b-8ad1-d7847e7337b7	kyfQy2ZCjFv3aT5ZX22XMSsme/JE11BnR2LQIs525V+GsEsQ5KZdbc+EQkuyybkRrXgOoi2cO+TVXO35SM74Rg==	2026-03-07 21:27:46.54286+00	2026-02-28 21:27:46.542753+00	\N	435668be-b38c-417d-979a-7ac88b8b4174
1c8ff4ca-1e3e-46eb-94f9-f3a3c896eae2	lXFnnlyId013v4Yb7rkAb4IaEuY1a9Fkai/jzhcAvWL8ugduggUJ74l5AVlEhlzF8oSRgH4f6xeZI2293W1w2Q==	2026-03-08 00:26:39.974719+00	2026-03-01 00:26:39.974717+00	2026-03-01 01:06:38.573334+00	435668be-b38c-417d-979a-7ac88b8b4174
3e6f7ab7-935e-4e1f-8601-f0a871a97ad1	DTdxZxtgUo2MFtbOiWiuqLv95s1eoL2ve0le8x0PIpjsliz1cC8gj6XV9SBCJ+5qNji4cDlE8Opd5VWZ70Zc0Q==	2026-03-07 22:13:16.754412+00	2026-02-28 22:13:16.754329+00	\N	435668be-b38c-417d-979a-7ac88b8b4174
b8301674-75b7-4638-bd1d-53bf165870f2	6Z4E1JOzwXo6Mn2kwJfGPNf0eO8aidKLv3AUfWuHwbqRVr2KRD0Xn1jRTn3b4vGq4els0mAXM6yMSH7dMBBwkw==	2026-03-07 21:27:46.542849+00	2026-02-28 21:27:46.542753+00	2026-02-28 22:13:16.713318+00	435668be-b38c-417d-979a-7ac88b8b4174
e2b14793-0f12-48cb-88b1-73290cc1f67f	1c2pt2+G1xvGcrbisqCe9TX2RGUPOzsT8s1jIAVkEcUJF9Hqqkqm4biGVyHdKXBoyshhmNxAVVe7pdLx67xELA==	2026-03-07 22:13:16.754396+00	2026-02-28 22:13:16.754322+00	\N	435668be-b38c-417d-979a-7ac88b8b4174
e7dc4340-a9d8-4162-b229-7c813cdeb6b3	v1GJPoL8kVZ9i5Cc1BweG5YzjHVa5zYuCETzgfjHfm2aytwhGzWhfu1hPKnB1Z8cCuBy3v7CnVVWJr3Z92VZXg==	2026-03-08 01:06:38.573592+00	2026-03-01 01:06:38.573591+00	2026-03-01 01:41:38.176343+00	435668be-b38c-417d-979a-7ac88b8b4174
7f68071d-9164-4fe8-85c7-f796b9b9e3db	7cEVo54LWjezbgpRrun0Ym/pOpXZ+QSFJTG2/8Y7dwcxIA6I8EdP+WTs9bTqABc5gl7CEpXTq9qCAw4v+Qpvjw==	2026-03-09 01:15:49.454362+00	2026-03-02 01:15:49.454263+00	2026-03-02 03:00:54.244881+00	435668be-b38c-417d-979a-7ac88b8b4174
f90191a9-3ba4-4a43-b1a1-abaeba9800c4	rXW9hfBwEPKfJ4YAyzKftACjLxS8uQq831tAqDl1bsK3K/Ezw7KcamhME64hcBunSMAcEeMUmZAmE6TmsNYJeQ==	2026-03-08 19:53:39.606499+00	2026-03-01 19:53:39.606437+00	\N	435668be-b38c-417d-979a-7ac88b8b4174
3daf0ed5-3a89-477c-b3b7-fc10242cc380	Oc73MvEn07RETtngTRiJx/hjDUutxKQRknMuZSzr5zuamBLu1Ka37r601fAapGc3uy5Ol+z9ogvcHWxO8QUSeQ==	2026-03-08 01:41:38.193622+00	2026-03-01 01:41:38.193563+00	2026-03-01 19:53:39.585489+00	435668be-b38c-417d-979a-7ac88b8b4174
494231eb-3d31-4be4-a147-69ce94333094	GcfhwKqkoWUgr8bUKfNVPkkl+rquxG0UHqyfA561A3B77vLh5Oo39J0MjErUV64raXaD/Y6R5xILdxrSIbeT1A==	2026-03-08 19:53:39.60651+00	2026-03-01 19:53:39.606443+00	2026-03-01 20:28:35.815398+00	435668be-b38c-417d-979a-7ac88b8b4174
e469f3aa-0055-41bf-9b1e-a5ed1b738b1d	9Wow1dUDR0kT8BON9ZUWuQSGi29O9BOstJBwxj1cci1ZofHql0l5IVcm7EvNRxgomE+aTLerNH+6qLqx9Ruvww==	2026-03-08 20:28:35.818014+00	2026-03-01 20:28:35.818014+00	2026-03-02 01:15:49.413468+00	435668be-b38c-417d-979a-7ac88b8b4174
890edceb-1181-46a0-836f-da9419e69b06	z2GffWfhAj4BsxyW0sm6E2DrUhXuOJ0d5G9knCU928kJF8FuSpHIf57o7iX2qsx5+uu3opbUgeMI45CJUO3y8w==	2026-03-09 01:15:49.454435+00	2026-03-02 01:15:49.454263+00	\N	435668be-b38c-417d-979a-7ac88b8b4174
2bcb688b-e05e-41a4-9971-b10fd249ef4a	eojF7yrYR8LSNklFuF/uvm/+kUV/EBSdPcxPzTitHSj5QVI4BzQqV8Wy++63O0ycs7ndmzTPVpuvThZWu4L+hw==	2026-03-10 21:52:35.586839+00	2026-03-03 21:52:35.586701+00	\N	435668be-b38c-417d-979a-7ac88b8b4174
42aa5578-4f66-48dd-a6f4-ca2704db8235	lfVbk5FZcV2YvR5wAK58k/cj6U9wKl48qd1PFvh2G/kHZ9b7u6C3OXgxBSpmj0BW/5EM4G4kN29PXP8jF+xnDw==	2026-03-09 03:00:54.263095+00	2026-03-02 03:00:54.263033+00	2026-03-03 21:52:35.563277+00	435668be-b38c-417d-979a-7ac88b8b4174
b8126428-0686-4378-809b-4caa08a41f89	PVJlK4Na47aM0Ny4efIUjzxDn/OIbDaamhLW6YahcATD9jxQ1JZpT4lHuyoZKTmNoKGOPNz589fxMlu9WltdAg==	2026-03-10 21:52:35.586828+00	2026-03-03 21:52:35.586701+00	2026-03-03 22:26:21.475272+00	435668be-b38c-417d-979a-7ac88b8b4174
f0f9ad3d-469d-4ef7-9a91-937fc33b6dc6	k+R4Zm61YiO9pPMr3PdQDN2nBpuV3p6dPV1HYyXE8W837UTRdHP81W71ViXwJTUTvmFcCHBYLEZUPaO1/rSsdw==	2026-03-10 22:26:21.501085+00	2026-03-03 22:26:21.500978+00	\N	435668be-b38c-417d-979a-7ac88b8b4174
a240d0a0-6c6f-4882-9bcf-826136d03366	TTovToQWCU27XZF15/tI7/MRJwUIsE2SgaUljtos1G9SiDf33oYl6om7UBK5JNOZVcswopC67roFvcyl1Jn7fQ==	2026-03-10 22:59:00.86898+00	2026-03-03 22:59:00.868926+00	2026-03-03 23:30:18.475391+00	435668be-b38c-417d-979a-7ac88b8b4174
bca27b58-6620-46a2-9583-2b9bdc37e9a2	StUBCNJdxn/UohmfujnKD20TED/nXu5CCFlcbG37KCl9OjyQBrglrSU9Bzn3aHlG2U9gjpY32Pbx7/OBQezHmw==	2026-03-10 23:30:18.490626+00	2026-03-03 23:30:18.49058+00	2026-03-04 00:04:26.407063+00	435668be-b38c-417d-979a-7ac88b8b4174
4df6849f-17a6-48f5-949a-d6e5387b9367	n0LCfZhtW3OkgGy3QJg8GBbn1e0qjMQ+T8Ii8frAWrqiEawwDGuqGsR2Rat8KV/M9XlviM6Xj86wpchTRzn+PQ==	2026-03-11 00:04:26.422946+00	2026-03-04 00:04:26.422902+00	2026-03-04 00:36:32.019974+00	435668be-b38c-417d-979a-7ac88b8b4174
2dadb04a-f1bf-4d0d-a32b-d2a31314b1e2	CrKlNCmVhS/U8jAXIi5iuOpL/I7oMjmP8GypWFoKSDNxbD5bhECqFFUblmITEueEpomG60AlTmeXYsw+WoOD9A==	2026-03-11 00:36:32.040573+00	2026-03-04 00:36:32.040265+00	2026-03-04 01:09:22.249651+00	435668be-b38c-417d-979a-7ac88b8b4174
807292f7-98ff-47d2-97b4-3c34cbc06306	kSeK8Ep3gQonjzs9UjehHYn3v8J4IAoSlP7Sx+1KmiPq7QR7N/KUSLuHX2BcD7H/svQ8ELuCfE3jXigVVKjy+g==	2026-03-11 02:22:14.090207+00	2026-03-04 02:22:14.090206+00	\N	435668be-b38c-417d-979a-7ac88b8b4174
d4144e2c-bb66-469e-a814-cf7d6f8c3815	vRDnrKMxBjiFaCMmFemGRUmt4i75FYgLlX491rR1JMyMd8rayUOGCFyQ6E5c8Lafv40DOvMrhbQs3Odgscvb7A==	2026-03-11 01:09:22.251723+00	2026-03-04 01:09:22.251723+00	2026-03-04 02:22:14.080467+00	435668be-b38c-417d-979a-7ac88b8b4174
1db2aefb-c6bb-4f75-a588-9f67606ed5a6	YP7e5maZRQM8iYh31fezDxVD4xJWiKk9zH+MrV5rPvL2u123SvptAvZ22kyjYD+bBa5WzQ0ArJCkoO2Sye8XBg==	2026-03-11 02:22:14.090207+00	2026-03-04 02:22:14.090207+00	2026-03-05 22:14:42.429088+00	435668be-b38c-417d-979a-7ac88b8b4174
2c89f719-9ddd-4a86-96fe-acb6a76333a1	WRe+rBxQfn5o0DlZnEAsx7T6mfIIFExq6QxGlQzMgqTH/RqznRgInSN8zvWI0UZODx306YPLrXNJyJxBs4z7mA==	2026-03-12 22:14:42.445914+00	2026-03-05 22:14:42.445868+00	\N	435668be-b38c-417d-979a-7ac88b8b4174
eb147d35-fe00-4a95-ae0b-3c2d158646cd	PYq7kzRWKpt/e2hXgiForORyosV//x7tvccfVhjX97nFHrum+JQxAFpacOJNh05q3w9eJrN2C6imU1z8XM8pig==	2026-03-12 22:14:42.445908+00	2026-03-05 22:14:42.44586+00	2026-03-05 22:45:17.634884+00	435668be-b38c-417d-979a-7ac88b8b4174
6f940831-d313-4aab-b1f0-714da9f73d8e	Y42Ychw9dQsJtPMuBePJjRRc5zjwOEpGdoFm9ulVrJS0hJXnFW4/Xpf8mCubakG8sdR1QAuWlIdiILpTA/rA/g==	2026-03-12 22:45:17.648302+00	2026-03-05 22:45:17.648258+00	2026-03-05 23:31:03.091579+00	435668be-b38c-417d-979a-7ac88b8b4174
962259d5-be47-4d10-bd56-c42e67a250bf	dMfQdKBaVr6uCLPeH02IsvdNuC+H1C525kUEq6V9drTwxXwFdSfa5ef/juTrLGbVnTUDXbubkBZRle9P7EJpHg==	2026-03-12 23:31:03.112525+00	2026-03-05 23:31:03.112468+00	\N	435668be-b38c-417d-979a-7ac88b8b4174
815349cb-cb31-4976-8760-c3fa72d52a0e	MUyWlaQZwxRv4xYdFhKuyOrpkn64E6MFziQthRqGo/xp5Rg8v338GSSqOEHoY5hFq6KeTcq1YPLAifKE1SPWQQ==	2026-03-12 23:31:03.112863+00	2026-03-05 23:31:03.112863+00	2026-03-06 00:06:00.57644+00	435668be-b38c-417d-979a-7ac88b8b4174
9e889f7c-34ba-4389-bb15-0b62a8a56b16	459hqVG6e95raAeG++liENp7feZTLoSvWUr4o1OW86w4SxG7/Jqxh2wmNV7amrRd599mSObPjkHlADA1Z5LYlA==	2026-03-13 00:06:00.581814+00	2026-03-06 00:06:00.581814+00	2026-03-06 00:52:04.714623+00	435668be-b38c-417d-979a-7ac88b8b4174
2bdee9e0-3eed-48d8-82de-ff48cd7ceee5	OYCIfQRJqOh7VksK01E7QMwwLLgTPUVLEerjYpYpfZJQYLZrpvSIT/YLoV0rN3PLT1z/5s8vQUCxPOZ6GCz3Iw==	2026-03-13 00:52:04.727157+00	2026-03-06 00:52:04.727157+00	\N	435668be-b38c-417d-979a-7ac88b8b4174
1581a0fa-7e3b-46b7-9a9c-fb362bc5b8fc	8Lqor1AGt9teZ7ZFvbgmzLcyf1vWhkNIKb/wSPtsMTdpqterubEWNZDBLoiOR9luTCrdPh67pPMLdd+acITwZQ==	2026-03-13 00:52:04.731142+00	2026-03-06 00:52:04.731142+00	2026-03-07 01:09:29.662003+00	435668be-b38c-417d-979a-7ac88b8b4174
21d4068a-4687-40ef-af4e-ebf733ed15b7	7KDH6LrhiMoZrNHyeAVoS4huEfrqPNT7ziwjLhQ7up++hJNXDHK5SUVK0bqMbNenPOmcR4JQ7XwgJJR/eotbvQ==	2026-03-15 03:49:26.939546+00	2026-03-08 03:49:26.939222+00	2026-03-09 00:25:35.70396+00	435668be-b38c-417d-979a-7ac88b8b4174
108f3a7e-59d4-493e-ae21-2c2a766c954f	SLQLOb2mto4YBv1sAHpL7s/iDn6rqHf/rqa4XZ8WFYAwv/ojrfcQbpJ2MsReHiuz97cLzW53wZfdl14KKaPEhw==	2026-03-14 03:07:27.199432+00	2026-03-07 03:07:27.199227+00	\N	435668be-b38c-417d-979a-7ac88b8b4174
9fa40233-c60e-46c6-ad59-2486fb4ae63f	igt6qDyE+BkMo+GlAuHQPpqWD2JIg0074trz+3fO9dbc6HyHA3g0KpeSe3dOyfHtANUcFR3bwnpOA3VfvsaOuw==	2026-03-14 01:09:29.682082+00	2026-03-07 01:09:29.681955+00	2026-03-07 03:07:27.17639+00	435668be-b38c-417d-979a-7ac88b8b4174
0d3bd4ec-bb4d-4069-96d8-f47fc47b8049	ouvgb0lIKqKwhqqNM+ZUhDIammJE12lC4sBXsvB4OHNcvaBomMBirltAXfBTtm6TWnskWOVy4/C0M4ajTA55VQ==	2026-03-14 03:07:27.199424+00	2026-03-07 03:07:27.199221+00	\N	435668be-b38c-417d-979a-7ac88b8b4174
d263f311-f654-4d9d-9fc2-150f4640ddfa	veFi/rLa3k+4BbbGaEWMODkGLVpeezQv1ljcnQx+qoluNHd66IegJtsQJVcLzeTj/nvV6/YFR5sJHjkfZ987oQ==	2026-03-14 22:05:05.95747+00	2026-03-07 22:05:05.957397+00	\N	435668be-b38c-417d-979a-7ac88b8b4174
8873d715-628a-45b8-9b60-03d91bb63e0d	6nzRwjuXW38u3kdjHK4t4XbdYkPgp7VFd3b2nmu6djTp2e7aqaeY47PHwgiw9Pb6aCWRSZcOk7T6VMGqodSkyw==	2026-03-14 03:07:27.199441+00	2026-03-07 03:07:27.199231+00	2026-03-07 22:05:05.932721+00	435668be-b38c-417d-979a-7ac88b8b4174
81c93523-0001-4fd7-9650-8404a0793d08	osEXxz9RsB7qzXTASbRtKsreDbqVSawViHA4tTys4u4MTo1UfJxTx/6C7gCGregqyB2TLndnTGrduORdxxTtvw==	2026-03-14 22:05:05.95749+00	2026-03-07 22:05:05.957423+00	\N	435668be-b38c-417d-979a-7ac88b8b4174
7edc28e5-124a-4400-afc3-647d56036321	NXTPUb/5jqdL+yyxjAe2TXu9/N9Ws8/djOumKoC2TPIkjjDtXHK9Vk0NI8/+UKoBBgxXOmQN4ajNmoWb8Bw45g==	2026-03-14 22:05:05.957494+00	2026-03-07 22:05:05.957428+00	2026-03-08 02:42:15.415333+00	435668be-b38c-417d-979a-7ac88b8b4174
2b18a1d0-40df-4f04-b739-c65a109b0e2c	p4XIfJKPSz14xoM3x58oKF8jqDYLlq4VMbvf0d/QU2lSBxDxY4yMBvamw2EuMLvE36XQAQLA+sPS4jjLZ+bDAA==	2026-03-15 02:42:15.441192+00	2026-03-08 02:42:15.441122+00	2026-03-08 03:16:28.913139+00	435668be-b38c-417d-979a-7ac88b8b4174
c49bb4f8-5f53-4413-942b-a5bc9358036f	REQyg3HeJnPlPBh43D9uAv2Ds/7jOk0xpNpYNOzBl4408JhwNOoYri1mVS6S363/Mum+k4oXW69S92gWpp4xvw==	2026-03-15 03:49:26.939519+00	2026-03-08 03:49:26.939519+00	\N	435668be-b38c-417d-979a-7ac88b8b4174
eb50ec09-39f9-4a66-b8d0-3158901acdef	YRYo8kGLRyV2oKhRoiNDHdT6bkJkuJEbICAFtcocElkPPWpV9NToa2QxAXPZlVFegMMSGliDkStAZwX43zMwjA==	2026-03-15 03:49:26.939557+00	2026-03-08 03:49:26.939556+00	\N	435668be-b38c-417d-979a-7ac88b8b4174
af0e5471-ec5f-4835-a323-dcbee6543b83	OO6y8yFYjEyvplDOmrTadVl2NXm+DsC8mto2sXUkmw63selOlumJW3yja7h35Ey4TDyqb3rFsgeRYyNsD2qCvA==	2026-03-15 03:49:26.939345+00	2026-03-08 03:49:26.939247+00	\N	435668be-b38c-417d-979a-7ac88b8b4174
53d841dd-15b1-4aab-9e07-74cc1c0c206b	QVN8iaI3rlJYHDUmfnO0SBqhLcFR2ybT5pPQk7LDJ4oRl1K9FNCTI1ePaLUDvpzzs97vnvcG9IIoImp8uLuzTg==	2026-03-15 03:16:28.927563+00	2026-03-08 03:16:28.927514+00	2026-03-08 03:49:26.912019+00	435668be-b38c-417d-979a-7ac88b8b4174
cc54e3f3-977a-4968-bf98-e740839bb11e	m0MPm4av2Y+V8DPzHGXN540paHLMFq91KDVwzj/UnvmO1Oa0IMOH7PfPPuapZ8YQrI5POUvg5K2mifVaf24kqQ==	2026-03-15 03:49:26.939299+00	2026-03-08 03:49:26.939222+00	\N	435668be-b38c-417d-979a-7ac88b8b4174
79b9f57e-94a3-4166-b638-055724ee0461	LpIdl0CnXObXwK9jwTuW0IxqUg4z/PpMD9/hQAxaUnKGM7MjNYUK1qE0xhfpsmqkJbvdLKLAXI0HRn2UPYR4ZA==	2026-03-16 00:25:35.72733+00	2026-03-09 00:25:35.727229+00	\N	435668be-b38c-417d-979a-7ac88b8b4174
f993d631-62d7-47ed-b5b9-5bfbdefa4a8d	NiLpGF8IE702vmjv5V2zSl5TLQe0IHxCBsaoN43vahLlEkrQRD0S2k0WQGw0GG/Tf+GCZEkqhXy1DLnZi6TfmQ==	2026-03-16 00:25:35.727336+00	2026-03-09 00:25:35.727252+00	\N	435668be-b38c-417d-979a-7ac88b8b4174
44f58d8f-c54f-4a70-919a-2e81dcdb0f72	/HHHQv9EkjmvvurmAZrggVdNi4HY7/f9DsZiMJSA4q0+tlAVgKbtelMYZzgB3o0ExFFkywi+qJdwccTE5nGs5g==	2026-03-16 00:25:35.727344+00	2026-03-09 00:25:35.727282+00	\N	435668be-b38c-417d-979a-7ac88b8b4174
abce5216-1c46-48aa-851d-3aebd7c437cc	hpamvzoUJHx1CqwCRN3zuKYSCARviMLdTKZthYjdnPZBjSsVZLD8aW7ib7bmCfIWd8Bvc/aIZej37CZX7RJgMg==	2026-03-16 00:25:35.727321+00	2026-03-09 00:25:35.727229+00	\N	435668be-b38c-417d-979a-7ac88b8b4174
f750c505-64fb-466f-ac3c-184f3fa4b171	M07be1/46ljlWR3065EUeNi6NJ0byPi7ccaJoOZ9G5J2aHKKCalrQ0Hjde0OmSABJnC9zF+k+cEjFOOWL4+5Rg==	2026-03-16 00:25:35.727354+00	2026-03-09 00:25:35.727286+00	2026-03-09 01:00:32.853007+00	435668be-b38c-417d-979a-7ac88b8b4174
a8c7bff8-d08f-4cc2-81a8-2eecbd8cd189	D2PbigaVRMfAHLg9ZCz70LfrW4YBmH7C/MCVj7Rs9N7wV6Y22MlKz6gADVi8+r/NxJ6nSqaCvR3TXT80NSHrHg==	2026-03-16 01:00:32.872412+00	2026-03-09 01:00:32.872365+00	2026-03-09 01:58:58.665459+00	435668be-b38c-417d-979a-7ac88b8b4174
824d5088-f76f-4519-a04d-e5d51b4cac62	3DZyJ8I7yRbvxrywlI1VnImE2jU52jzATKdg7tIxyc6ZAc5jv+mF702vKxxu3hKfmAcinzDVbJhxLtuhbUIuKg==	2026-03-16 01:58:58.686536+00	2026-03-09 01:58:58.68646+00	\N	435668be-b38c-417d-979a-7ac88b8b4174
072fc0b3-f836-49f4-ad20-ef4bf5f7452a	oCG4/YuQn9n9nQo21Is+ujOZf3PEPhi9ChNjCaN6fEN/Gr8k38YWraRUVIyaW6Wz8b7nSHyxOhu+sUHgp34e8g==	2026-03-16 02:09:06.047101+00	2026-03-09 02:09:06.04707+00	2026-03-09 02:43:35.751343+00	435668be-b38c-417d-979a-7ac88b8b4174
e2aaf8b4-930d-4282-83ee-a25d045c75cb	KS7WPfsC1935IxQoms22Enx3U2qmEGysTVvGp98kxDY845ga3AQuElZG+5IG7ADmHtZA85GH9qDrEGITF5W+cw==	2026-03-16 02:43:35.771739+00	2026-03-09 02:43:35.771687+00	\N	435668be-b38c-417d-979a-7ac88b8b4174
16023bd6-e2fb-4762-963a-284b0540363a	OOaoltjxSlUvZ950h75qaDKx6T6Kau+K2KykSwIODPOr8FtQ+Sub/xWWI37UVU/WTsqPA3b5Yz2MvS+IdMc1pQ==	2026-03-16 02:55:54.847407+00	2026-03-09 02:55:54.847406+00	\N	435668be-b38c-417d-979a-7ac88b8b4174
399368c5-c4af-47a4-8dd8-f2a24db5882f	LeLhIvQO4t3nCs18MuSLNV6sB5Q1er6Y8wlwrux97FTv5xhrrxyuVBUZz3CdVbGOoJRDwSPcbuj3NVnBEP6jTA==	2026-03-19 01:29:20.50157+00	2026-03-12 01:29:20.501512+00	2026-03-12 02:00:01.01813+00	435668be-b38c-417d-979a-7ac88b8b4174
a5c66ade-3ee0-4c8d-8b55-6bf2fc7de920	dSJ6xGRq65r7BL9mSGFEBIAHxKZYTdbgqGKL1dMPV7z19pCBU89rfN4SFy7bETWKJQW/o6M4ooDFBvv7fGTnfQ==	2026-03-19 02:00:01.050747+00	2026-03-12 02:00:01.050642+00	2026-03-12 02:30:06.008092+00	435668be-b38c-417d-979a-7ac88b8b4174
3296296b-1741-45d3-a338-a322fefa9383	PYdBD60dpbT776hSgqApq42Cra01nLao1BYFzQoDS3/kVdQwQdf5kLZluswxlDEiY3BzqrQGtPSaO/jHK+Geew==	2026-03-19 02:30:06.042878+00	2026-03-12 02:30:06.042808+00	\N	435668be-b38c-417d-979a-7ac88b8b4174
8649ece6-5bc7-4cf4-aa54-6aa233a13fbf	VGx//h6lpZgP5crKHuH0Mwndht0m271/FBp05spg1seL9Jj2vtrSosJhs9kaxRtvxpALC1+9SVqrZ9T3fAv8nw==	2026-03-19 22:13:46.949064+00	2026-03-12 22:13:46.949026+00	\N	435668be-b38c-417d-979a-7ac88b8b4174
1174a423-53d4-4228-b69a-abad2d3cdae2	n0Dyx8WdViI5onE4wef17LP5CuP+es24I1By/YmBzYCiDbDjpV9hV9RQdwDzcJrvmKv1OUOvJMfKcx7ETMu8hQ==	2026-03-19 23:03:15.127885+00	2026-03-12 23:03:15.127836+00	2026-03-12 23:33:16.084198+00	435668be-b38c-417d-979a-7ac88b8b4174
0be0335f-a403-49e0-a1f6-1bb64e50c8b2	Uz9Ow6BW//91Y6zbn5nqrbf/rjLM4Rs3Nc2ZfsOzdurbUKlGZYguNOxiM0TyJmkFvlFpQ9myPsp6mIN6YcNkIg==	2026-03-19 23:33:16.085322+00	2026-03-12 23:33:16.085322+00	\N	435668be-b38c-417d-979a-7ac88b8b4174
\.


--
-- Data for Name: ReturnInvoiceItems; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY public."ReturnInvoiceItems" ("Id", "ReturnInvoiceId", "ProductId", "Quantity", "UnitPrice") FROM stdin;
\.


--
-- Data for Name: ReturnInvoices; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY public."ReturnInvoices" ("Id", "ReturnNo", "OriginalInvoiceId", "Reason", "Notes", "RefundAmount", "CreatedAt", "CreatedBy") FROM stdin;
\.


--
-- Data for Name: Shifts; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY public."Shifts" ("Id", "CashierId", "StartTime", "EndTime", "OpeningCash", "TotalSales", "TotalCashIn", "TotalCashOut", "ExpectedCash", "ActualCash", "Difference", "Status", "Notes") FROM stdin;
853f6e1b-65ac-4a6a-b82d-d86b12ec54fc	435668be-b38c-417d-979a-7ac88b8b4174	2026-02-25 01:25:52.831166+00	\N	50000.0	0	0	0	50000.0	0	0	1	\N
efbbeb4a-8673-4973-bb53-884876cb043d	435668be-b38c-417d-979a-7ac88b8b4174	2026-03-12 23:10:42.626633+00	\N	500.0	0	0	0	500.0	0	0	0	\N
\.


--
-- Data for Name: ShopSettings; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY public."ShopSettings" ("Id", "ShopName", "Address", "Phone", "Phone2", "CommercialRegNo", "TaxNumber", "LogoBase64", "ReceiptFooter", "VatEnabled", "DefaultVatRate", "CurrencySymbol", "CurrencyCode", "UpdatedAt", "SmsApiKey", "SmsSenderId", "SmsProvider", "BackupPath") FROM stdin;
32ca9b86-f8a5-42ae-9809-61e4b42248e2	الإخلاص	المحمودية		\N	\N	\N	\N	الاخلاص لتجهيز العرائس	f	14.00	ج.م	EGP	2026-03-04 02:28:00.221932+00	\N	\N	\N	\N
\.


--
-- Data for Name: StockAdjustments; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY public."StockAdjustments" ("Id", "ProductId", "Type", "QuantityAdjusted", "Cost", "Reason", "CreatedAt", "CreatedBy") FROM stdin;
\.


--
-- Data for Name: StockMovements; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY public."StockMovements" ("Id", "ProductId", "Type", "Quantity", "BalanceAfter", "ReferenceId", "ReferenceNumber", "Notes", "CreatedAt", "CreatedBy") FROM stdin;
\.


--
-- Data for Name: Suppliers; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY public."Suppliers" ("Id", "Name", "Phone", "Address", "CompanyName", "Type", "OpeningBalance", "AccountId", "CreatedAt") FROM stdin;
d4c917f8-755b-464a-8a2a-3df3a5c14b05	توكيل العربى	012456478	بنها الكبرى 	العربى	0	0.00	\N	2026-02-25 01:10:12.9081+00
\.


--
-- Data for Name: Users; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY public."Users" ("Id", "Username", "PasswordHash", "FullName", "Role", "IsActive", "CreatedAt") FROM stdin;
2aa14527-0386-4329-aacc-7cec30b5ade1	ali	$2a$12$OWP2evqOyoZjXriWvt0XK.4cZe8iSdewS.0TNAXg6zBcQ/UuKFXY.	Ali	Manager	t	2026-03-04 02:30:22.714481+00
435668be-b38c-417d-979a-7ac88b8b4174	admin	$2a$12$03.okm2APYokOp4KzPZVl.Tq979V7RRRo8kFuaKSEaURNK1xMngga	المدير	Admin	t	2026-02-24 01:26:10.647637+00
\.


--
-- Data for Name: __EFMigrationsHistory; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY public."__EFMigrationsHistory" ("MigrationId", "ProductVersion") FROM stdin;
20260224012544_AddInvoiceFields	9.0.0
20260224015227_MakeSupplierFieldsNullable	9.0.0
20260224020332_RelaxNavigationProperties	9.0.0
20260224020504_FixPurchaseProductIdType	9.0.0
20260224023245_UnifyGuidIds_InvoiceFields_BCrypt	9.0.0
20260224023635_AddShopSettings	9.0.0
20260224163400_AddSmsSettingsToShopSettings	9.0.0
20260224220946_AddImageUrlToProduct	9.0.0
20260224225828_AddShiftEntity	9.0.0
20260224235630_SoftDeleteCustomer	9.0.0
20260224235718_UpdateExistingCustomersIsActive	9.0.0
20260225001339_AddRefreshTokens	9.0.0
20260225001423_AddProductIsActive	9.0.0
20260225024035_AddStockAdjustments	9.0.0
20260226002156_FixProductGlobalBarcodeNullable	9.0.0
20260301231044_AddPurchaseInvoiceStatus	9.0.0
20260301232947_AddIsClosedToJournalEntry	9.0.0
20260301233852_AddBridalFieldsToInvoice	9.0.0
20260302000102_AddAuditLogFeature	9.0.0
20260303213758_AddSmsProviderToSettings	9.0.0
20260306030613_AddPaymentReferenceToInvoice	9.0.0
20260306031416_AddStockMovements	9.0.0
20260308033311_AddDynamicExpenseCategories	9.0.0
20260309010056_AddExpenseReceiptImagePath	9.0.0
20260309012637_AddCustomBackupPath	9.0.0
\.


--
-- Name: Accounts PK_Accounts; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."Accounts"
    ADD CONSTRAINT "PK_Accounts" PRIMARY KEY ("Id");


--
-- Name: AuditLogs PK_AuditLogs; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."AuditLogs"
    ADD CONSTRAINT "PK_AuditLogs" PRIMARY KEY ("Id");


--
-- Name: Bundles PK_Bundles; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."Bundles"
    ADD CONSTRAINT "PK_Bundles" PRIMARY KEY ("Id");


--
-- Name: CashTransactions PK_CashTransactions; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."CashTransactions"
    ADD CONSTRAINT "PK_CashTransactions" PRIMARY KEY ("Id");


--
-- Name: Customers PK_Customers; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."Customers"
    ADD CONSTRAINT "PK_Customers" PRIMARY KEY ("Id");


--
-- Name: ExpenseCategories PK_ExpenseCategories; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."ExpenseCategories"
    ADD CONSTRAINT "PK_ExpenseCategories" PRIMARY KEY ("Id");


--
-- Name: Expenses PK_Expenses; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."Expenses"
    ADD CONSTRAINT "PK_Expenses" PRIMARY KEY ("Id");


--
-- Name: Installments PK_Installments; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."Installments"
    ADD CONSTRAINT "PK_Installments" PRIMARY KEY ("Id");


--
-- Name: InvoiceItems PK_InvoiceItems; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."InvoiceItems"
    ADD CONSTRAINT "PK_InvoiceItems" PRIMARY KEY ("Id");


--
-- Name: Invoices PK_Invoices; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."Invoices"
    ADD CONSTRAINT "PK_Invoices" PRIMARY KEY ("Id");


--
-- Name: JournalEntries PK_JournalEntries; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."JournalEntries"
    ADD CONSTRAINT "PK_JournalEntries" PRIMARY KEY ("Id");


--
-- Name: JournalEntryLines PK_JournalEntryLines; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."JournalEntryLines"
    ADD CONSTRAINT "PK_JournalEntryLines" PRIMARY KEY ("Id");


--
-- Name: ProductUnits PK_ProductUnits; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."ProductUnits"
    ADD CONSTRAINT "PK_ProductUnits" PRIMARY KEY ("Id");


--
-- Name: Products PK_Products; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."Products"
    ADD CONSTRAINT "PK_Products" PRIMARY KEY ("Id");


--
-- Name: PurchaseInvoiceItems PK_PurchaseInvoiceItems; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."PurchaseInvoiceItems"
    ADD CONSTRAINT "PK_PurchaseInvoiceItems" PRIMARY KEY ("Id");


--
-- Name: PurchaseInvoices PK_PurchaseInvoices; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."PurchaseInvoices"
    ADD CONSTRAINT "PK_PurchaseInvoices" PRIMARY KEY ("Id");


--
-- Name: RefreshTokens PK_RefreshTokens; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."RefreshTokens"
    ADD CONSTRAINT "PK_RefreshTokens" PRIMARY KEY ("Id");


--
-- Name: ReturnInvoiceItems PK_ReturnInvoiceItems; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."ReturnInvoiceItems"
    ADD CONSTRAINT "PK_ReturnInvoiceItems" PRIMARY KEY ("Id");


--
-- Name: ReturnInvoices PK_ReturnInvoices; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."ReturnInvoices"
    ADD CONSTRAINT "PK_ReturnInvoices" PRIMARY KEY ("Id");


--
-- Name: Shifts PK_Shifts; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."Shifts"
    ADD CONSTRAINT "PK_Shifts" PRIMARY KEY ("Id");


--
-- Name: ShopSettings PK_ShopSettings; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."ShopSettings"
    ADD CONSTRAINT "PK_ShopSettings" PRIMARY KEY ("Id");


--
-- Name: StockAdjustments PK_StockAdjustments; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."StockAdjustments"
    ADD CONSTRAINT "PK_StockAdjustments" PRIMARY KEY ("Id");


--
-- Name: StockMovements PK_StockMovements; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."StockMovements"
    ADD CONSTRAINT "PK_StockMovements" PRIMARY KEY ("Id");


--
-- Name: Suppliers PK_Suppliers; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."Suppliers"
    ADD CONSTRAINT "PK_Suppliers" PRIMARY KEY ("Id");


--
-- Name: Users PK_Users; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."Users"
    ADD CONSTRAINT "PK_Users" PRIMARY KEY ("Id");


--
-- Name: __EFMigrationsHistory PK___EFMigrationsHistory; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."__EFMigrationsHistory"
    ADD CONSTRAINT "PK___EFMigrationsHistory" PRIMARY KEY ("MigrationId");


--
-- Name: IX_Accounts_ParentAccountId; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX "IX_Accounts_ParentAccountId" ON public."Accounts" USING btree ("ParentAccountId");


--
-- Name: IX_Bundles_ParentProductId; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX "IX_Bundles_ParentProductId" ON public."Bundles" USING btree ("ParentProductId");


--
-- Name: IX_Bundles_SubProductId; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX "IX_Bundles_SubProductId" ON public."Bundles" USING btree ("SubProductId");


--
-- Name: IX_CashTransactions_JournalEntryId; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX "IX_CashTransactions_JournalEntryId" ON public."CashTransactions" USING btree ("JournalEntryId");


--
-- Name: IX_CashTransactions_TargetAccountId; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX "IX_CashTransactions_TargetAccountId" ON public."CashTransactions" USING btree ("TargetAccountId");


--
-- Name: IX_Expenses_CategoryId; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX "IX_Expenses_CategoryId" ON public."Expenses" USING btree ("CategoryId");


--
-- Name: IX_Expenses_JournalEntryId; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX "IX_Expenses_JournalEntryId" ON public."Expenses" USING btree ("JournalEntryId");


--
-- Name: IX_Installments_InvoiceId; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX "IX_Installments_InvoiceId" ON public."Installments" USING btree ("InvoiceId");


--
-- Name: IX_InvoiceItems_InvoiceId; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX "IX_InvoiceItems_InvoiceId" ON public."InvoiceItems" USING btree ("InvoiceId");


--
-- Name: IX_InvoiceItems_ProductId; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX "IX_InvoiceItems_ProductId" ON public."InvoiceItems" USING btree ("ProductId");


--
-- Name: IX_Invoices_CustomerId; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX "IX_Invoices_CustomerId" ON public."Invoices" USING btree ("CustomerId");


--
-- Name: IX_JournalEntryLines_AccountId; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX "IX_JournalEntryLines_AccountId" ON public."JournalEntryLines" USING btree ("AccountId");


--
-- Name: IX_JournalEntryLines_JournalEntryId; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX "IX_JournalEntryLines_JournalEntryId" ON public."JournalEntryLines" USING btree ("JournalEntryId");


--
-- Name: IX_ProductUnits_ProductId; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX "IX_ProductUnits_ProductId" ON public."ProductUnits" USING btree ("ProductId");


--
-- Name: IX_Products_GlobalBarcode; Type: INDEX; Schema: public; Owner: admin
--

CREATE UNIQUE INDEX "IX_Products_GlobalBarcode" ON public."Products" USING btree ("GlobalBarcode") WHERE ("GlobalBarcode" IS NOT NULL);


--
-- Name: IX_PurchaseInvoiceItems_ProductId; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX "IX_PurchaseInvoiceItems_ProductId" ON public."PurchaseInvoiceItems" USING btree ("ProductId");


--
-- Name: IX_PurchaseInvoiceItems_PurchaseInvoiceId; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX "IX_PurchaseInvoiceItems_PurchaseInvoiceId" ON public."PurchaseInvoiceItems" USING btree ("PurchaseInvoiceId");


--
-- Name: IX_PurchaseInvoices_JournalEntryId; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX "IX_PurchaseInvoices_JournalEntryId" ON public."PurchaseInvoices" USING btree ("JournalEntryId");


--
-- Name: IX_PurchaseInvoices_SupplierId; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX "IX_PurchaseInvoices_SupplierId" ON public."PurchaseInvoices" USING btree ("SupplierId");


--
-- Name: IX_RefreshTokens_UserId; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX "IX_RefreshTokens_UserId" ON public."RefreshTokens" USING btree ("UserId");


--
-- Name: IX_ReturnInvoiceItems_ProductId; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX "IX_ReturnInvoiceItems_ProductId" ON public."ReturnInvoiceItems" USING btree ("ProductId");


--
-- Name: IX_ReturnInvoiceItems_ReturnInvoiceId; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX "IX_ReturnInvoiceItems_ReturnInvoiceId" ON public."ReturnInvoiceItems" USING btree ("ReturnInvoiceId");


--
-- Name: IX_ReturnInvoices_OriginalInvoiceId; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX "IX_ReturnInvoices_OriginalInvoiceId" ON public."ReturnInvoices" USING btree ("OriginalInvoiceId");


--
-- Name: IX_Shifts_CashierId; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX "IX_Shifts_CashierId" ON public."Shifts" USING btree ("CashierId");


--
-- Name: IX_StockAdjustments_ProductId; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX "IX_StockAdjustments_ProductId" ON public."StockAdjustments" USING btree ("ProductId");


--
-- Name: IX_StockMovements_ProductId; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX "IX_StockMovements_ProductId" ON public."StockMovements" USING btree ("ProductId");


--
-- Name: IX_Suppliers_AccountId; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX "IX_Suppliers_AccountId" ON public."Suppliers" USING btree ("AccountId");


--
-- Name: Accounts FK_Accounts_Accounts_ParentAccountId; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."Accounts"
    ADD CONSTRAINT "FK_Accounts_Accounts_ParentAccountId" FOREIGN KEY ("ParentAccountId") REFERENCES public."Accounts"("Id") ON DELETE RESTRICT;


--
-- Name: Bundles FK_Bundles_Products_ParentProductId; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."Bundles"
    ADD CONSTRAINT "FK_Bundles_Products_ParentProductId" FOREIGN KEY ("ParentProductId") REFERENCES public."Products"("Id") ON DELETE RESTRICT;


--
-- Name: Bundles FK_Bundles_Products_SubProductId; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."Bundles"
    ADD CONSTRAINT "FK_Bundles_Products_SubProductId" FOREIGN KEY ("SubProductId") REFERENCES public."Products"("Id") ON DELETE RESTRICT;


--
-- Name: CashTransactions FK_CashTransactions_Accounts_TargetAccountId; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."CashTransactions"
    ADD CONSTRAINT "FK_CashTransactions_Accounts_TargetAccountId" FOREIGN KEY ("TargetAccountId") REFERENCES public."Accounts"("Id");


--
-- Name: CashTransactions FK_CashTransactions_JournalEntries_JournalEntryId; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."CashTransactions"
    ADD CONSTRAINT "FK_CashTransactions_JournalEntries_JournalEntryId" FOREIGN KEY ("JournalEntryId") REFERENCES public."JournalEntries"("Id");


--
-- Name: Expenses FK_Expenses_ExpenseCategories_CategoryId; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."Expenses"
    ADD CONSTRAINT "FK_Expenses_ExpenseCategories_CategoryId" FOREIGN KEY ("CategoryId") REFERENCES public."ExpenseCategories"("Id") ON DELETE RESTRICT;


--
-- Name: Expenses FK_Expenses_JournalEntries_JournalEntryId; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."Expenses"
    ADD CONSTRAINT "FK_Expenses_JournalEntries_JournalEntryId" FOREIGN KEY ("JournalEntryId") REFERENCES public."JournalEntries"("Id");


--
-- Name: Installments FK_Installments_Invoices_InvoiceId; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."Installments"
    ADD CONSTRAINT "FK_Installments_Invoices_InvoiceId" FOREIGN KEY ("InvoiceId") REFERENCES public."Invoices"("Id") ON DELETE CASCADE;


--
-- Name: InvoiceItems FK_InvoiceItems_Invoices_InvoiceId; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."InvoiceItems"
    ADD CONSTRAINT "FK_InvoiceItems_Invoices_InvoiceId" FOREIGN KEY ("InvoiceId") REFERENCES public."Invoices"("Id") ON DELETE CASCADE;


--
-- Name: InvoiceItems FK_InvoiceItems_Products_ProductId; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."InvoiceItems"
    ADD CONSTRAINT "FK_InvoiceItems_Products_ProductId" FOREIGN KEY ("ProductId") REFERENCES public."Products"("Id") ON DELETE CASCADE;


--
-- Name: Invoices FK_Invoices_Customers_CustomerId; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."Invoices"
    ADD CONSTRAINT "FK_Invoices_Customers_CustomerId" FOREIGN KEY ("CustomerId") REFERENCES public."Customers"("Id") ON DELETE RESTRICT;


--
-- Name: JournalEntryLines FK_JournalEntryLines_Accounts_AccountId; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."JournalEntryLines"
    ADD CONSTRAINT "FK_JournalEntryLines_Accounts_AccountId" FOREIGN KEY ("AccountId") REFERENCES public."Accounts"("Id") ON DELETE CASCADE;


--
-- Name: JournalEntryLines FK_JournalEntryLines_JournalEntries_JournalEntryId; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."JournalEntryLines"
    ADD CONSTRAINT "FK_JournalEntryLines_JournalEntries_JournalEntryId" FOREIGN KEY ("JournalEntryId") REFERENCES public."JournalEntries"("Id") ON DELETE CASCADE;


--
-- Name: ProductUnits FK_ProductUnits_Products_ProductId; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."ProductUnits"
    ADD CONSTRAINT "FK_ProductUnits_Products_ProductId" FOREIGN KEY ("ProductId") REFERENCES public."Products"("Id") ON DELETE CASCADE;


--
-- Name: PurchaseInvoiceItems FK_PurchaseInvoiceItems_Products_ProductId; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."PurchaseInvoiceItems"
    ADD CONSTRAINT "FK_PurchaseInvoiceItems_Products_ProductId" FOREIGN KEY ("ProductId") REFERENCES public."Products"("Id") ON DELETE CASCADE;


--
-- Name: PurchaseInvoiceItems FK_PurchaseInvoiceItems_PurchaseInvoices_PurchaseInvoiceId; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."PurchaseInvoiceItems"
    ADD CONSTRAINT "FK_PurchaseInvoiceItems_PurchaseInvoices_PurchaseInvoiceId" FOREIGN KEY ("PurchaseInvoiceId") REFERENCES public."PurchaseInvoices"("Id") ON DELETE CASCADE;


--
-- Name: PurchaseInvoices FK_PurchaseInvoices_JournalEntries_JournalEntryId; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."PurchaseInvoices"
    ADD CONSTRAINT "FK_PurchaseInvoices_JournalEntries_JournalEntryId" FOREIGN KEY ("JournalEntryId") REFERENCES public."JournalEntries"("Id");


--
-- Name: PurchaseInvoices FK_PurchaseInvoices_Suppliers_SupplierId; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."PurchaseInvoices"
    ADD CONSTRAINT "FK_PurchaseInvoices_Suppliers_SupplierId" FOREIGN KEY ("SupplierId") REFERENCES public."Suppliers"("Id") ON DELETE CASCADE;


--
-- Name: RefreshTokens FK_RefreshTokens_Users_UserId; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."RefreshTokens"
    ADD CONSTRAINT "FK_RefreshTokens_Users_UserId" FOREIGN KEY ("UserId") REFERENCES public."Users"("Id") ON DELETE CASCADE;


--
-- Name: ReturnInvoiceItems FK_ReturnInvoiceItems_Products_ProductId; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."ReturnInvoiceItems"
    ADD CONSTRAINT "FK_ReturnInvoiceItems_Products_ProductId" FOREIGN KEY ("ProductId") REFERENCES public."Products"("Id") ON DELETE RESTRICT;


--
-- Name: ReturnInvoiceItems FK_ReturnInvoiceItems_ReturnInvoices_ReturnInvoiceId; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."ReturnInvoiceItems"
    ADD CONSTRAINT "FK_ReturnInvoiceItems_ReturnInvoices_ReturnInvoiceId" FOREIGN KEY ("ReturnInvoiceId") REFERENCES public."ReturnInvoices"("Id") ON DELETE CASCADE;


--
-- Name: ReturnInvoices FK_ReturnInvoices_Invoices_OriginalInvoiceId; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."ReturnInvoices"
    ADD CONSTRAINT "FK_ReturnInvoices_Invoices_OriginalInvoiceId" FOREIGN KEY ("OriginalInvoiceId") REFERENCES public."Invoices"("Id") ON DELETE RESTRICT;


--
-- Name: Shifts FK_Shifts_Users_CashierId; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."Shifts"
    ADD CONSTRAINT "FK_Shifts_Users_CashierId" FOREIGN KEY ("CashierId") REFERENCES public."Users"("Id") ON DELETE RESTRICT;


--
-- Name: StockAdjustments FK_StockAdjustments_Products_ProductId; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."StockAdjustments"
    ADD CONSTRAINT "FK_StockAdjustments_Products_ProductId" FOREIGN KEY ("ProductId") REFERENCES public."Products"("Id") ON DELETE CASCADE;


--
-- Name: StockMovements FK_StockMovements_Products_ProductId; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."StockMovements"
    ADD CONSTRAINT "FK_StockMovements_Products_ProductId" FOREIGN KEY ("ProductId") REFERENCES public."Products"("Id") ON DELETE CASCADE;


--
-- Name: Suppliers FK_Suppliers_Accounts_AccountId; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."Suppliers"
    ADD CONSTRAINT "FK_Suppliers_Accounts_AccountId" FOREIGN KEY ("AccountId") REFERENCES public."Accounts"("Id");


--
-- PostgreSQL database dump complete
--

\unrestrict YqcgOEoNToEZgwnOr2OnYcZifoDbeIHIXANlLQiTHbII9sKBFr9iqsczGRH6FWS

