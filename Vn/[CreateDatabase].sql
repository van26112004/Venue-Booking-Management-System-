---TẠO DATABASE
use master
go
create database QuanLyDatPhong
go
use QuanLyDatPhong
go

---TẠO BẢNG
---Tạo bảng chi tiết phòng
create table CHITIETPHONG
(
	MaPhong int primary key,
	TenPhong nvarchar(50),
	CoSo nvarchar(10),
	PhiThue int,
   SucChua int,
   TinhTrangPhP nvarchar(50) 
)
go
---Tạo bảng Thời khoá biểu
create table TKB
( MaLopHP char(10),
TenHP nvarchar(100),
Ca int,
Phong nvarchar(10),
Thu int,
TGBD date,
TGKT date
)

---Tạo bảng Người mượn
create table NGUOIMUON
(
	MaNguoiMuon nvarchar(50) primary key,
	Ten nvarchar(max),
	DonVi nvarchar(50),
	SDT nchar(10),
	Email nvarchar(200)
)
go
---Tạo bảng Ca mượn
create table CAMUON
(
	MaCa int primary key,
	TGBatDau time,
    TGKetThuc time
)
go

---Tạo bảng người quản lý
Create table NGUOIQL
(
	MaNguoiQL nvarchar(50) primary key,
	Ten nvarchar(max),
	SDT nchar(10),
	Email nvarchar(200)
)
GO

---Tạo bảng dịch vụ kèm
create table DICHVUKEM
(
	MaDVu int primary key,
	TenDVu nvarchar(100),
	GiaDVu int
)
go

---Tạo bảng Đặt mượn
create table DATMUON
(
ID_DatMuon INT IDENTITY(1,1) PRIMARY KEY,
ID_NguoiMuon nvarchar(50),
TenNguoiMuon nvarchar(max),
DonVi nvarchar(50),
SDT nchar(10),
Email nvarchar(200),
ID_PhP int,
Ten_PhP nvarchar(50),
CoSo nvarchar(10),
TenDvuKem nvarchar(100),
ID_Ca int,
NgayDky datetime,
NgaySD datetime,
ID_NguoiQL nvarchar(50),
status nvarchar(50)
)
---Tạo bảng Hoá đơn
CREATE table HOADON
(
ID_HoaDon INT IDENTITY(1,1) PRIMARY KEY,
ID_DatMuon int,
TenNguoiMuon nvarchar(max),
Ten_PhP nvarchar(50),
GiaPhong int, 
TenDvuKem nvarchar(MAX),
GiaDvuKem int,
CheckIn datetime,
CheckOut datetime,
PhuPhi int,
TongTien int,
TinhTrangThanhToan nvarchar(50)
)
---Tạo bảng Thanh toán
CREATE TABLE THANHTOAN (
ID_ThanhToan INT IDENTITY(1,1) PRIMARY KEY,
ID_HoaDon INT,
TenNguoiMuon nvarchar(max),
HinhThucThanhToan nvarchar(4)
)

-- Tạo các khoá ngoại
-- Khóa ngoại từ DATMUON đến NGUOIMUON
ALTER TABLE DATMUON
ADD CONSTRAINT FK_DatMuon_NguoiMuon 
FOREIGN KEY (ID_NguoiMuon) REFERENCES NGUOIMUON (MaNguoiMuon);
GO

-- Khóa ngoại từ DATMUON đến CHITIETPHONG
ALTER TABLE DATMUON
ADD CONSTRAINT FK_DatMuon_ChiTietPhong 
FOREIGN KEY (ID_PhP) REFERENCES CHITIETPHONG (MAPHONG);
GO

-- Khóa ngoại từ DATMUON đến CaMuon
ALTER TABLE DATMUON
ADD CONSTRAINT FK_DatMuon_CaMuon 
FOREIGN KEY (ID_Ca) REFERENCES CaMuon (MaCa);
GO

-- Khóa ngoại từ DATMUON đến NGUOIQL
ALTER TABLE DATMUON
ADD CONSTRAINT FK_DatMuon_NguoiQL
FOREIGN KEY (ID_NguoiQL) REFERENCES NGUOIQL (MaNguoiQL);
GO

-- Khóa ngoại từ HOADON đến DATMUON
ALTER TABLE HOADON
ADD CONSTRAINT FK_HoaDon_DatMuon
FOREIGN KEY (ID_DatMuon) REFERENCES DATMUON (ID_DatMuon);
GO

-- Khóa ngoại từ TKB đến CaMuon
ALTER TABLE TKB
ADD CONSTRAINT FK_TKB_CaMuon
FOREIGN KEY (Ca) REFERENCES CaMuon (MaCa);
GO

-- Khóa ngoại từ THANHTOAN đến HOADON
ALTER TABLE THANHTOAN
ADD CONSTRAINT FK_ThanhToan_HoaDon
FOREIGN KEY (Id_HoaDon) REFERENCES HOADON (ID_HoaDon);