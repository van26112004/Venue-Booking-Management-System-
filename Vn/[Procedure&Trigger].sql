
-- QUERY CHỨC NĂNG
use QuanLyDatPhong
go
-- 1. DÀNH CHO NGƯỜI DÙNG
-- CHỨC NĂNG TÌM PHÒNG THEO NGÀY TRỐNG VÀ CA

CREATE PROCEDURE TIMPHONG
(
	@CaID INT,
	@NgaySD DATETIME,
    @CoSo NVARCHAR(50)
)
AS
BEGIN
    -- Tạo bảng tạm #BANGPHONGTRONG nếu chưa tồn tại
    IF OBJECT_ID('tempdb..#BANGPHONGTRONG') IS NULL
    BEGIN
        CREATE TABLE #BANGPHONGTRONG (
            TenPhong NVARCHAR(50),
            SucChua INT,
            CoSo NVARCHAR(200),
			PhiThue int,
			TinhTrangPhP nvarchar(50)
        );
    END;

    -- Xóa dữ liệu cũ trong bảng tạm #BANGPHONGTRONG
    TRUNCATE TABLE #BANGPHONGTRONG;

    -- Biến đếm số lượng phòng trống
    DECLARE @PhongTrong INT = 0;

    -- Thêm dữ liệu mới vào bảng tạm #BANGPHONGTRONG dựa trên các tham số đầu vào
    INSERT INTO #BANGPHONGTRONG (TenPhong, SucChua, CoSo,PhiThue, TinhTrangPhP)
    SELECT 
        p.TenPhong, 
        p.SucChua, 
        p.CoSo,
		p.PhiThue,
		p.TinhTrangPhP
    FROM 
        CHITIETPHONG p
    WHERE 
        CoSo = @CoSo
        AND p.MaPhong NOT IN (
            SELECT ID_PhP 
            FROM DATMUON 
            WHERE NgaySD = @NgaySD 
            AND ID_Ca = @CaID 
            AND status = 'Da duyet' or status='Da CheckIn'
        )
        AND p.MaPhong NOT IN (
            SELECT MaPhong 
            FROM CHITIETPHONG 
            WHERE TenPhong IN (
                SELECT TenHP 
                FROM TKB 
                WHERE @NgaySD BETWEEN TGBD AND TGKT 
                AND DATEPART(WEEKDAY, @NgaySD) = Thu 
                AND ca = @CaID
            )
        );

    -- Kiểm tra số lượng phòng trống
    SELECT @PhongTrong = COUNT(*) FROM #BANGPHONGTRONG;

    -- In thông báo nếu không có phòng trống
    IF @PhongTrong = 0
    BEGIN
        PRINT(N'Không có phòng trống');
    END
    ELSE
    BEGIN
        -- Trả về kết quả nếu có phòng trống
        SELECT * FROM #BANGPHONGTRONG;
    END;
END;
--THỬ
EXEC TIMPHONG 2,'2024/01/06', 'TD'

-- CHỨC NĂNG ĐẶT PHÒNG 

CREATE PROCEDURE DATPHONG
(
    @MSSV nvarchar(50),
    @Ten nvarchar(50),
    @Donvi nvarchar(50),
    @Sdt nvarchar(50),
    @Email nvarchar(50),
    @TenPhong nvarchar(50),
    @CoSo nvarchar(50),
    @TenDVuKem nvarchar(max),
    @CaID int,
    @NgaySD datetime
)
AS
BEGIN
    DECLARE @NgayDK DATETIME
    DECLARE @IDPhong INT
    DECLARE @TinhTrangPhP NVARCHAR(50)
    DECLARE @status NVARCHAR(50) = 'Dang Dat'

    SET @NgayDK = GETDATE()
    SET @IDPhong = (SELECT MaPhong FROM CHITIETPHONG WHERE TENPHONG = @TenPhong AND CoSo = @CoSo)
    -- Kiểm tra trạng thái phòng
    SELECT @TinhTrangPhP = TinhTrangPhP
    FROM CHITIETPHONG
    WHERE MaPhong = @IDPhong;

    IF @TinhTrangPhP <> N'San sang'
    BEGIN
        PRINT N'Phòng chưa sẵn sàng. Không thể đặt phòng.';
        RETURN;
    END
    -- Kiểm tra nếu phòng đã được đặt hoặc sử dụng để dạy học
    IF EXISTS (
        SELECT 1 
        FROM DATMUON 
        WHERE NgaySD = @NgaySD AND ID_Ca = @CaID AND ID_PhP = @IDPhong
    )
    BEGIN
        PRINT N'Phòng đã bị đặt rồi';
        RETURN;
    END
    IF EXISTS (
        SELECT 1 
        FROM TKB 
        WHERE @NgaySD BETWEEN TGBD AND TGKT 
        AND DATEPART(WEEKDAY, @NgaySD) = thu 
        AND ca = @CaID AND Phong = (SELECT TenPhong FROM CHITIETPHONG WHERE MaPhong = @IDPhong)
    )
    BEGIN
        PRINT N'Không thể đặt vì phòng đã dùng để dạy học';
        RETURN;
    END
    -- Nếu sinh viên chưa từng mượn phòng thì cập nhật thông tin mới vào bảng NGUOIMUON
    IF NOT EXISTS (SELECT 1 FROM NGUOIMUON WHERE MaNguoiMuon = @MSSV)
    BEGIN
        INSERT INTO NGUOIMUON (MaNguoiMuon, Ten, DonVi, SDT, Email)
        VALUES (@MSSV, @Ten, @Donvi, @Sdt, @Email)
    END
    -- Thực hiện chèn thông tin đặt mượn vào bảng DATMUON
    INSERT INTO DATMUON (ID_NguoiMuon, TenNguoiMuon, DonVi, SDT, Email, ID_PhP, Ten_PhP, CoSo, TenDvuKem, ID_Ca, NgayDky, NgaySD, status)
    VALUES (@MSSV, @Ten, @Donvi, @Sdt, @Email, @IDPhong, @TenPhong, @CoSo, @TenDVuKem, @CaID, @NgayDK, @NgaySD, @status)

    PRINT N'Đặt Phòng Thành Công'
    SELECT * FROM DATMUON WHERE ID_NguoiMuon = @MSSV AND NgaySD = @NgaySD AND ID_Ca = @CaID
END;
-- CHẠY THỬ

EXEC DATPHONG '2256210048','Nguyen Le Tam Anh', 'Luu tru hoc', '0965887485', '2256210048@hcmussh.edu.vn', 'A-203', 'TD', 'Ban backdrop,Treo bandroll',2, '2024/11/03'

-- CHỨC NĂNG CHECKIN

CREATE PROCEDURE CHECKIN
(
    @ID_DatMuon INT
)
AS
BEGIN

    DECLARE @MaCa INT;
    DECLARE @ID_HoaDon INT;
    DECLARE @tenNgMuon NVARCHAR(50);
    DECLARE @TenPhP NVARCHAR(50);
    DECLARE @GiaPhong INT;
    DECLARE @TenDvuKem NVARCHAR(50);
    DECLARE @GiaDvuKem INT;
    DECLARE @NgaySD DATETIME;
    DECLARE @CheckIn DATETIME;
	declare @GiaTongDvu int;
	declare @status nvarchar(50);
    SET @CheckIn = GETDATE();

if @status not in (select status from DATMUON where status='Da duyet' or status= 'Da CheckIn'or status='Da hoan thanh' and ID_DatMuon=@ID_DatMuon)
print(N'Không được duyệt')
else 
 -- Lấy giá trị MaCa từ bảng DATMUON
    SET @MaCa = (SELECT ID_Ca FROM DATMUON WHERE ID_DatMuon = @ID_DatMuon);
 -- Lấy giá trị TenDVukem từ bảng DATMUON
    SET @TenDvuKem = (SELECT TenDvuKem FROM DATMUON WHERE ID_DatMuon = @ID_DatMuon);

	-- Kiểm tra số lượng dịch vụ kèm nhập vào
    DECLARE @NumDVKem INT
    SET @NumDVKem = (SELECT COUNT(*) FROM STRING_SPLIT(@TenDVuKem, ','))

    -- Nếu số lượng dịch vụ kèm từ 2 trở lên, thực hiện tạo bảng phụ và tính giá tổng cộng
    IF @NumDVKem >= 2
    BEGIN
        -- Tạo bảng phụ để lưu các dịch vụ kèm và tính tổng giá
        DECLARE @TempDVKem TABLE (IDDVu int, GiaDVu int)

        -- Chèn các dịch vụ kèm vào bảng phụ và tính tổng giá
        INSERT INTO @TempDVKem (IDDVu, GiaDVu)
        SELECT MaDVu, GiaDVu
        FROM DICHVUKEM
        WHERE TenDVu IN (SELECT value FROM STRING_SPLIT(@TenDVuKem, ','))

        -- Tính tổng giá của các dịch vụ kèm
        SET @GiaTongDvu = (SELECT SUM(GiaDVu) FROM @TempDVKem)

        -- Thực hiện check in nếu ID_DatMuon được duyệt
        BEGIN
		
            -- Lấy giá trị ID_HoaDon mới được tạo
            SET @ID_HoaDon = SCOPE_IDENTITY();

            -- Lấy thông tin người mượn, phòng 
            SELECT @tenNgMuon = ng.Ten,
                   @TenPhP = p.TENPHONG,
                   @GiaPhong = p.PHITHUE

            FROM NGUOIMUON ng
            JOIN DATMUON dm ON ng.MaNguoiMuon = dm.ID_NguoiMuon
            JOIN CHITIETPHONG p ON p.MAPHONG = dm.ID_PhP
            WHERE dm.ID_DatMuon = @ID_DatMuon;

            -- Thêm thông tin vào bảng HOADON
            INSERT INTO HOADON (ID_DatMuon, TenNguoiMuon, Ten_PhP, GiaPhong, TenDvuKem, GiaDvuKem, CheckIn)
            VALUES			   (@ID_DatMuon, @tenNgMuon, @TenPhP, @GiaPhong, @TenDvuKem, @GiaTongDvu, @CheckIn);

            -- Hiển thị thông tin trong bảng THANHTOAN
            SELECT * FROM HOADON WHERE ID_DatMuon = @ID_DatMuon;

            -- Cập nhật trạng thái của đặt mượn
            UPDATE DATMUON 
            SET status = 'Da CheckIn' 
            WHERE ID_DatMuon = @ID_DatMuon;
        END
    END
END;
---THỬ (Vui lòng chỉnh giờ máy tính)
EXEC CHECKIN 41

--CHỨC NĂNG CHECKOUT

CREATE PROCEDURE CHECKOUT
(
    @ID_DatMuon INT
)
AS
BEGIN
    DECLARE @ID_HoaDon INT
    DECLARE @GiaPhong INT
    DECLARE @GiaDvuKem INT
	declare @CheckIn datetime
    DECLARE @CheckOut DATETIME
    DECLARE @Diff INT
    DECLARE @TGTre INT
    DECLARE @TGKTCa TIME
	DECLARE @TGKT DATETIME
    DECLARE @PhuPhi INT
    DECLARE @TongTien INT
    DECLARE @TinhTrangThanhToan NVARCHAR(50)

    SET @CheckOut = GETDATE()

    -- Kiểm tra nếu ID_DatMuon không tồn tại trong HOADON
    IF NOT EXISTS (SELECT 1 FROM HOADON WHERE ID_DatMuon = @ID_DatMuon)
    BEGIN
        PRINT N'Mã không tồn tại'
        RETURN
    END

    -- Lấy thông tin từ các bảng liên quan
    SELECT 
        @ID_HoaDon = h.ID_HoaDon,
        @GiaPhong = p.PHITHUE,
        @TGKTCa = cm.TGKetThuc,
		@CheckIn = h.CheckIn,
		@GiaDvuKem= h.GiaDvuKem
    FROM 
        DATMUON dm
    JOIN 
        NGUOIMUON nm ON nm.MaNguoiMuon = dm.ID_NguoiMuon
    JOIN 
        CHITIETPHONG p ON p.MaPhong = dm.ID_PhP
    JOIN 
        CAMUON cm ON cm.MaCa = dm.ID_Ca
    JOIN 
        HOADON h ON h.ID_DatMuon = dm.ID_DatMuon
    WHERE 
        dm.ID_DatMuon = @ID_DatMuon

    -- Kiểm tra thời gian CheckIn và CheckOut
    IF @CheckIn > @CheckOut
    BEGIN
        PRINT N'Thời gian check out không hợp lệ'
        RETURN
    END
        SET @TGKT = DATEADD(MILLISECOND, DATEDIFF(MILLISECOND, '00:00:00', @TGKTCa), CAST(CAST(@CheckIn AS DATE) AS DATETIME));
    -- Tính toán thời gian trễ và phụ phí
    IF @CheckOut > CAST(@TGKTCa AS datetime)
	-- Tạo TGKT bằng cách kết hợp ngày check in với giờ kết thúc ca
       
    BEGIN
            SET @Diff = DATEDIFF(HOUR, @TGKT, @CheckOut);
    END
    ELSE
    BEGIN
        SET @Diff = 0
    END

    SET @TGTre = cast (@Diff as int)
    SET @PhuPhi = @GiaPhong/4.5 * @TGTre
		SET @PhuPhi = ROUND(@PhuPhi, 0);
    SET @TongTien = @GiaPhong + @GiaDvuKem + @PhuPhi
    SET @TinhTrangThanhToan = 'Chua thanh toan'

    -- Cập nhật bảng HOADON
    UPDATE HOADON
    SET 
        CheckOut = @CheckOut,
        PhuPhi = @PhuPhi,
        TongTien = @TongTien,
        TinhTrangThanhToan = @TinhTrangThanhToan
    WHERE 
        ID_DatMuon = @ID_DatMuon

    -- Trả về thông tin đã cập nhật
    SELECT * FROM HOADON WHERE ID_DatMuon = @ID_DatMuon
END
---THỬ (Vui lòng chỉnh giờ máy tính)

EXEC CHECKOUT 41

-- CHỨC NĂNG CAPNHATTHANHTOAN

CREATE PROCEDURE CAPNHATTHANHTOAN
(
    @ID_HoaDon INT,
    @HinhThucThanhToan NVARCHAR(4)  -- CK, TT
)
AS
BEGIN
    DECLARE @ID_DatMuon INT;
    DECLARE @TenNguoiMuon NVARCHAR(MAX);
    DECLARE @Status NVARCHAR(50) = 'Da thanh toan';
    DECLARE @StatusDatMuon NVARCHAR(50) = 'Da hoan thanh';

    -- Lấy giá trị ID_DatMuon và TenNguoiMuon từ bảng HOADON
    SELECT @ID_DatMuon = ID_DatMuon, @TenNguoiMuon = TenNguoiMuon
    FROM HOADON
    WHERE ID_HoaDon = @ID_HoaDon;

    -- Kiểm tra nếu ID_HoaDon tồn tại trong bảng HOADON
    IF @ID_DatMuon IS NULL
    BEGIN
        PRINT N'ID_HoaDon không tồn tại.';
        RETURN;
    END

    -- Thêm thông tin vào bảng THANHTOAN
    INSERT INTO THANHTOAN (ID_HoaDon, TenNguoiMuon, HinhThucThanhToan)
    VALUES (@ID_HoaDon, @TenNguoiMuon, @HinhThucThanhToan);

    -- Cập nhật trạng thái trong bảng HOADON
    UPDATE HOADON
    SET TinhTrangThanhToan = @Status
    WHERE ID_HoaDon = @ID_HoaDon;

    -- Cập nhật trạng thái trong bảng DATMUON
    UPDATE DATMUON
    SET status = @StatusDatMuon
    WHERE ID_DatMuon = @ID_DatMuon;
	SELECT * FROM THANHTOAN WHERE ID_HoaDon=@ID_HoaDon

END;
--THỬ
EXEC CAPNHATTHANHTOAN 26, 'CK'

-- CHỨC NĂNG CHO XEM LỊCH SỬ ĐẶT CỦA SINH VIÊN

CREATE PROCEDURE XemLichSuDatPhong
    @MSSV NVARCHAR(50)  -- Đầu vào: Mã số sinh viên của người dùng
AS
BEGIN
    SELECT 
        dm.ID_DatMuon AS MaDatMuon,
        p.TenPhong,
        dm.NgayDky AS ThoiGianDat,
        dm.NgaySD AS ThoiGianSuDung,
        dm.TenDvuKem AS DichVuKemTheo,
        dm.status AS Status  -- Thêm cột Status
    FROM DATMUON dm
    INNER JOIN CHITIETPHONG p ON dm.ID_PhP = p.MaPhong
    WHERE dm.ID_NguoiMuon = @MSSV;
END;
----THỬ

EXEC XemLichSuDatPhong '2103456789'

-- CHỨC NĂNG XEM LỊCH SỬ THÔNG BÁO

CREATE PROCEDURE XemThongBaoTinNhan
    @MSSV NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    -- Tạo bảng tạm thời để lưu thông báo và tin nhắn
    CREATE TABLE #ThongBaoTinNhan (
        NgayGui DATETIME,
        LoaiThongBao NVARCHAR(100),
        NoiDung NVARCHAR(MAX)
    );

    -- Lấy thông báo về nhắc nhở thanh toán từ bảng HOADON
    INSERT INTO #ThongBaoTinNhan (NgayGui, LoaiThongBao, NoiDung)
    SELECT CheckOut, N'Nhắc nhở thanh toán', N'Bạn chưa thanh toán hóa đơn. Vui lòng thanh toán trước ngày ' + CONVERT(NVARCHAR(10), CheckOut, 103)
    FROM HOADON h
	join DATMUON d on d.ID_DatMuon=h.ID_DatMuon
    WHERE ID_NguoiMuon = @MSSV AND TinhTrangThanhToan = N'Chua thanh toan';

    -- Lấy thông báo về lịch sử đặt phòng từ bảng DATMUON
    INSERT INTO #ThongBaoTinNhan (NgayGui, LoaiThongBao, NoiDung)
    SELECT d.NgayDky, N'Lịch sử đặt phòng', N'Bạn đã đặt phòng ' + Ten_PhP + N' vào ngày ' + CONVERT(NVARCHAR(10), NgaySD, 103) + N' từ ' + CONVERT(NVARCHAR(5), c.TGBatDau, 108) + N' đến ' + CONVERT(NVARCHAR(5), c.TGKetThuc, 108)
    FROM DATMUON d join CAMUON c on d.ID_Ca=c.MaCa
    WHERE ID_NguoiMuon = @MSSV;

    -- Lấy thông báo về cập nhật thông tin từ bảng NGUOIMUON
    INSERT INTO #ThongBaoTinNhan (NgayGui, LoaiThongBao, NoiDung)
    SELECT GETDATE(), N'Thông báo cập nhật', N'Thông tin cá nhân của bạn đã được cập nhật thành công.'
    FROM NGUOIMUON
    WHERE MaNguoiMuon = @MSSV;

    -- Lấy thông báo về việc đã thanh toán từ bảng DATMUON
    INSERT INTO #ThongBaoTinNhan (NgayGui, LoaiThongBao, NoiDung)
    SELECT GETDATE(), N'Thông báo đã thanh toán', N'Đơn đặt phòng của bạn đã được thanh toán và hoàn thành.'
    FROM DATMUON
    WHERE ID_NguoiMuon = @MSSV AND status = N'Da hoan thanh';

    -- Hiển thị thông báo và tin nhắn
    SELECT NgayGui, LoaiThongBao, NoiDung
    FROM #ThongBaoTinNhan
    ORDER BY NgayGui DESC;

    -- Xóa bảng tạm thời
    DROP TABLE #ThongBaoTinNhan;
END;
---thử

exec XemThongBaoTinNhan '2103456789'

-- 2. DÀNH CHO NGƯỜI QUẢN LÝ

-- CHỨC NĂNG DUYỆT PHÒNG

CREATE PROCEDURE DUYETPHONG
(
    @MaNQL NVARCHAR(50), 
    @Choose NVARCHAR(50), 
    @MaMuon INT
)
AS
BEGIN
    -- Chuyển đổi @Choose thành trạng thái tương ứng
    DECLARE @NewStatus NVARCHAR(50);
    
    IF @Choose = 'Yes'
        SET @NewStatus = 'Da Duyet';
    ELSE IF @Choose = 'No'
        SET @NewStatus = 'Tu Choi';
    ELSE
        SET @NewStatus = NULL;

    -- Kiểm tra nếu @NewStatus không hợp lệ
    IF @NewStatus IS NOT NULL AND @MaMuon IN (SELECT ID_DatMuon FROM DATMUON)
    BEGIN
        UPDATE DATMUON
        SET ID_NguoiQL = @MaNQL, status = @NewStatus
        WHERE ID_DatMuon = @MaMuon;

        SELECT * FROM DATMUON WHERE ID_DatMuon = @MaMuon;
    END
    ELSE
    BEGIN
        PRINT N'Trạng thái không hợp lệ hoặc mã mượn không tồn tại.';
    END
END;
----THỬ

EXEC DUYETPHONG 1, 'Yes', 51

-- CHỨC NĂNG XEM ĐƠN QUÁ HẠN CHECK OUT HOẶC CHƯA THANH TOÁN

CREATE PROCEDURE XemDonMuonPhongQuaHan
AS
BEGIN
    SET NOCOUNT ON;

    -- Tạo bảng tạm thời để lưu thông tin đơn mượn phòng quá hạn
    CREATE TABLE #DonMuonPhongQuaHan (
        ID_DatMuon INT,
        ID_NguoiMuon NVARCHAR(50),
        TenNguoiMuon NVARCHAR(MAX),
        DonVi NVARCHAR(50),
        SDT NCHAR(10),
        Email NVARCHAR(200),
        ID_PhP INT,
        Ten_PhP NVARCHAR(50),
        CoSo NVARCHAR(10),
        NgayDky DATETIME,
        NgaySD DATETIME,
        ID_NguoiQL NVARCHAR(50),
        status NVARCHAR(50),
        TinhTrangDon NVARCHAR(100)
    );

    -- Chèn các đơn mượn phòng quá giờ check out
    INSERT INTO #DonMuonPhongQuaHan
    SELECT dm.ID_DatMuon, dm.ID_NguoiMuon, dm.TenNguoiMuon, dm.DonVi, dm.SDT, dm.Email, 
           dm.ID_PhP, dm.Ten_PhP, dm.CoSo, dm.NgayDky, dm.NgaySD, dm.ID_NguoiQL, 
           dm.status, N'Quá giờ check out' AS TinhTrangDon
    FROM DATMUON dm
    JOIN HOADON hd ON dm.ID_DatMuon = hd.ID_DatMuon  
    WHERE (hd.CheckOut IS NULL OR hd.TinhTrangThanhToan IS NULL) AND dm.status <> 'Da hoan thanh';

    -- Chèn các đơn mượn phòng quá hạn thanh toán
    INSERT INTO #DonMuonPhongQuaHan
    SELECT dm.ID_DatMuon, dm.ID_NguoiMuon, dm.TenNguoiMuon, dm.DonVi, dm.SDT, dm.Email, 
           dm.ID_PhP, dm.Ten_PhP, dm.CoSo, dm.NgayDky, dm.NgaySD, dm.ID_NguoiQL, 
           dm.status, N'Quá hạn thanh toán (' + CONVERT(NVARCHAR(10), DATEDIFF(DAY, hd.CheckOut, GETDATE())) + N' ngày)' AS TinhTrangDon
    FROM DATMUON dm
    JOIN HOADON hd ON dm.ID_DatMuon = hd.ID_DatMuon
    WHERE hd.TinhTrangThanhToan = 'Chua thanh toan' AND DATEDIFF(DAY, hd.CheckOut, GETDATE()) > 0;

    -- Hiển thị thông tin các đơn mượn phòng quá hạn
    SELECT *
    FROM #DonMuonPhongQuaHan
    ORDER BY NgaySD DESC;

    -- Xóa bảng tạm thời
    DROP TABLE #DonMuonPhongQuaHan;
END;
----THỬ
EXEC XemDonMuonPhongQuaHan --- Chỉnh giờ để thử thanh toán trễ hạn (3/10/2024)

---- CHỨC NĂNG THÊM, XOÁ, SỬA PHÒNG
CREATE PROCEDURE QUANLYPHONG
    @Action NVARCHAR(10),
    @TenPhong NVARCHAR(50) = NULL,
    @CoSo NVARCHAR(50) = NULL,
    @PhiThue INT = NULL,  -- Chỉ sử dụng khi thêm phòng
    @SucChua INT = NULL,  -- Chỉ sử dụng khi thêm phòng
    @TinhTrangPhP NVARCHAR(50) = NULL,
    @MaPhong INT = NULL  -- Chỉ sử dụng khi cần cập nhật hoặc xóa
AS
BEGIN
    SET NOCOUNT ON;

    IF @Action = 'INSERT'
    BEGIN
        -- Kiểm tra các tham số bắt buộc
        IF @TenPhong IS NULL OR @CoSo IS NULL OR @PhiThue IS NULL OR @SucChua IS NULL OR @TinhTrangPhP IS NULL
        BEGIN
            PRINT N'Vui lòng cung cấp đầy đủ thông tin để thêm phòng.';
            RETURN;
        END

        DECLARE @NewMaPhong INT;
        
        -- Lấy mã phòng lớn nhất hiện có và cộng thêm 1
        SELECT @NewMaPhong = ISNULL(MAX(MaPhong), 0) + 1 FROM CHITIETPHONG;
        
        -- Thêm thông tin phòng mới với mã phòng tự động tăng
        INSERT INTO CHITIETPHONG (MaPhong, TenPhong, CoSo, PhiThue, SucChua, TinhTrangPhP)
        VALUES (@NewMaPhong, @TenPhong, @CoSo, @PhiThue, @SucChua, @TinhTrangPhP);

        PRINT N'Phòng đã được thêm thành công với mã phòng ' + CAST(@NewMaPhong AS NVARCHAR(10));
    END
    ELSE IF @Action = 'UPDATE'
    BEGIN
        -- Kiểm tra xem @MaPhong có được cung cấp hay không
        IF @MaPhong IS NULL
        BEGIN
            PRINT N'Vui lòng cung cấp mã phòng để cập nhật thông tin.';
            RETURN;
        END

        -- Kiểm tra ít nhất một giá trị để cập nhật
        IF @TenPhong IS NULL AND @CoSo IS NULL AND @PhiThue IS NULL AND @SucChua IS NULL AND @TinhTrangPhP IS NULL
        BEGIN
            PRINT N'Vui lòng cung cấp ít nhất một thông tin để cập nhật.';
            RETURN;
        END

        -- Sửa đổi thông tin phòng
        UPDATE CHITIETPHONG
        SET TenPhong = ISNULL(@TenPhong, TenPhong),
            CoSo = ISNULL(@CoSo, CoSo),
            PhiThue = ISNULL(@PhiThue, PhiThue),
            SucChua = ISNULL(@SucChua, SucChua),
            TinhTrangPhP = ISNULL(@TinhTrangPhP, TinhTrangPhP)
        WHERE MaPhong = @MaPhong;

        PRINT N'Thông tin phòng đã được cập nhật thành công';
    END
    ELSE IF @Action = 'DELETE'
    BEGIN
        -- Kiểm tra xem @MaPhong có được cung cấp hay không
        IF @MaPhong IS NULL
        BEGIN
            PRINT N'Vui lòng cung cấp mã phòng để xóa.';
            RETURN;
        END

        -- Xóa thông tin phòng
        DELETE FROM CHITIETPHONG
        WHERE MaPhong = @MaPhong;

        PRINT N'Phòng đã được xóa thành công';
    END
    ELSE
    BEGIN
        PRINT N'Action không hợp lệ. Vui lòng sử dụng INSERT, UPDATE hoặc DELETE.';
    END
END;
-- THỬ
EXEC QUANLYPHONG 'INSERT','A-109', 'TD',0,50, 'San sang'; ---THÊM
EXEC QUANLYPHONG 'UPDATE', 'A-109 Updated', 'TD Updated', 'Chua duoc dung', 161;---cập nhật
EXEC QUANLYPHONG 'DELETE', 'A-109', NULL, NULL,NULL,NULL, 161; ---xoá

-- CHỨC NĂNG THÊM, XOÁ, SỬA DỊCH VỤ KÈM

CREATE PROCEDURE QUANLYDICHVUKEM
    @Action NVARCHAR(10),
    @TenDVuKem NVARCHAR(MAX) = NULL,
    @Gia INT = NULL,
    @MaDVuKem INT = NULL OUTPUT  -- Thêm OUTPUT để trả về mã dịch vụ kèm mới
AS
BEGIN
    SET NOCOUNT ON;

    IF @Action = 'INSERT'
    BEGIN
        -- Tạo biến để lưu trữ mã dịch vụ kèm mới
        DECLARE @NewMaDVuKem INT;
        
        -- Lấy mã dịch vụ kèm lớn nhất hiện có và cộng thêm 1
        SELECT @NewMaDVuKem = ISNULL(MAX(MaDVu), 0) + 1 FROM DICHVUKEM;
        
        -- Thêm thông tin dịch vụ kèm mới với mã dịch vụ kèm tự động tăng
        INSERT INTO DICHVUKEM (MaDVu, TenDVu, GiaDVu)
        VALUES (@NewMaDVuKem, @TenDVuKem, @Gia);

        -- Trả về mã dịch vụ kèm mới cho người gọi procedure
        SET @MaDVuKem = @NewMaDVuKem;

        PRINT N'Dịch vụ kèm đã được thêm thành công với mã ' + CAST(@NewMaDVuKem AS NVARCHAR(10));
    END
    ELSE IF @Action = 'UPDATE'
    BEGIN
        -- Kiểm tra xem @MaDVuKem có được cung cấp hay không
        IF @MaDVuKem IS NULL
        BEGIN
            PRINT N'Vui lòng cung cấp mã dịch vụ kèm để cập nhật thông tin.';
            RETURN;
        END

        -- Sửa đổi thông tin dịch vụ kèm
        UPDATE DICHVUKEM
        SET TenDVu = @TenDVuKem,
            GiaDVu = @Gia
        WHERE MaDVu = @MaDVuKem;

        PRINT N'Thông tin dịch vụ kèm đã được cập nhật thành công';
    END
    ELSE IF @Action = 'DELETE'
    BEGIN
        -- Kiểm tra xem @MaDVuKem có được cung cấp hay không
        IF @MaDVuKem IS NULL
        BEGIN
            PRINT N'Vui lòng cung cấp mã dịch vụ kèm để xóa.';
            RETURN;
        END

        -- Xóa thông tin dịch vụ kèm
        DELETE FROM DICHVUKEM
        WHERE MaDVu = @MaDVuKem;

        PRINT N'Dịch vụ kèm đã được xóa thành công';
    END
    ELSE
    BEGIN
        PRINT N'Action không hợp lệ. Vui lòng sử dụng INSERT, UPDATE hoặc DELETE.';
    END
END;
-- THỬ
EXEC QUANLYDICHVUKEM 'INSERT', N'Dịch vụ quay số', 260000;

-- CHỨC NĂNG GỬI EMAIL NHẮC NHỞ THANH TOÁN CHO NHỮNG NGƯỜI DÙNG CÓ HÓA ĐƠN CHƯA THANH TOÁN
-- B1: TẠO PROC GỬI MAIL
CREATE PROCEDURE sp_send_dbmail
    @recipients NVARCHAR(255),
    @subject NVARCHAR(255),
    @body NVARCHAR(MAX),
    @profile_name NVARCHAR(MAX)
AS
BEGIN
    -- Gửi email
    EXEC msdb.dbo.sp_send_dbmail
        @profile_name = @profile_name,
        @recipients = @recipients,
        @subject = @subject,
        @body = @body;
END;
-- B2: TẠO PROC THỰC THI LỆNH GỬI MAIL
CREATE PROCEDURE GUITHONGBAONHAC
AS
BEGIN
    DECLARE @Email NVARCHAR(50);
    DECLARE @ProfileName NVARCHAR(MAX);

    DECLARE cur CURSOR FOR
    SELECT nm.Email, nm.Ten
    FROM NGUOIMUON nm
    JOIN DATMUON dm ON nm.MaNguoiMuon = dm.ID_NguoiMuon
    JOIN HOADON hd ON dm.ID_DatMuon = hd.ID_DatMuon
    WHERE hd.TinhTrangThanhToan = N'Chua thanh toan';

    OPEN cur;
    FETCH NEXT FROM cur INTO @Email, @ProfileName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC sp_send_dbmail @profile_name=@ProfileName, @recipients=@Email, @subject=N'Nhắc nhở thanh toán', @body=N'Bạn chưa thanh toán, vui lòng thanh toán sớm.';
        FETCH NEXT FROM cur INTO @Email, @ProfileName;
    END

    CLOSE cur;
    DEALLOCATE cur;
END;
--- THỬ
EXEC GUITHONGBAONHAC
-- KIỂM TRA
USE msdb;
GO
SELECT mailitem_id, Profile_id, recipients, subject, body
FROM sysmail_allitems
ORDER BY send_request_date DESC;

-- CHỨC NĂNG XEM BÁO CÁO TIỀN THU ĐƯỢC/SỐ PHÒNG ĐÃ CHO MƯỢN

CREATE PROCEDURE XEMBAOCAO
    @TuNgay DATETIME,
    @DenNgay DATETIME
AS
BEGIN
    -- Bảng thống kê số lượng phòng được đặt
    SELECT 
        COUNT(DISTINCT d.ID_DatMuon) AS SoLuongDatPhong,
        COUNT(DISTINCT d.ID_PhP) AS SoLuongPhongDuocDat,
        SUM(CASE WHEN h.TinhTrangThanhToan = N'Da thanh toan' THEN 1 ELSE 0 END) AS SoLuongDaThanhToan,
        SUM(CASE WHEN h.TinhTrangThanhToan = N'Chua thanh toan' THEN 1 ELSE 0 END) AS SoLuongChuaThanhToan
    FROM DATMUON d
    LEFT JOIN HOADON h ON d.ID_DatMuon = h.ID_DatMuon
    WHERE d.NgaySD BETWEEN @TuNgay AND @DenNgay;

    -- Bảng thống kê doanh thu từ các đơn đặt phòng
    SELECT 
        SUM(h.TongTien) AS TongDoanhThu
    FROM HOADON h
    JOIN DATMUON d ON h.ID_DatMuon = d.ID_DatMuon
    WHERE d.NgaySD BETWEEN @TuNgay AND @DenNgay
      AND h.TinhTrangThanhToan = N'Da thanh toan';

    -- Bảng chi tiết các phòng được đặt
    SELECT 
        d.ID_DatMuon,
        d.ID_NguoiMuon,
        d.TenNguoiMuon,
        d.Ten_PhP,
        d.CoSo,
        d.TenDvuKem,
        d.NgaySD,
        d.ID_Ca,
        h.TongTien,
        h.TinhTrangThanhToan
    FROM DATMUON d
    LEFT JOIN HOADON h ON d.ID_DatMuon = h.ID_DatMuon
    WHERE d.NgaySD BETWEEN @TuNgay AND @DenNgay;
END;
---THỬ
EXEC XEMBAOCAO '2023/01/01', '2023/03/1'

-- 3. TRIGGER KIỂM SOÁT DỮ LIỆU
-- Trigger: trg_CheckRoomAndPaymentBeforeAdding
CREATE TRIGGER trg_CheckRoomAndPaymentBeforeAdding
ON DATMUON
INSTEAD OF INSERT
AS
BEGIN
    DECLARE @ID_PhP INT;
    DECLARE @ID_NguoiMuon NVARCHAR(50);

    -- Lấy giá trị từ INSERTED để kiểm tra
    SELECT @ID_PhP = ID_PhP, @ID_NguoiMuon = ID_NguoiMuon
    FROM INSERTED;

    -- Kiểm tra nếu phòng tồn tại và tình trạng thanh toán của người mượn
    IF NOT EXISTS (SELECT 1 FROM CHITIETPHONG WHERE MaPhong = @ID_PhP)
    BEGIN
        PRINT N'Phòng không tồn tại.';
        ROLLBACK TRANSACTION;  -- Hủy bỏ giao dịch nếu điều kiện không thỏa mãn
        RETURN;
    END
    ELSE IF EXISTS (
        SELECT 1 
        FROM HOADON
        WHERE ID_DatMuon IN (SELECT ID_DatMuon FROM DATMUON WHERE ID_NguoiMuon = @ID_NguoiMuon)
        AND TinhTrangThanhToan = N'Chua thanh toan'
    )
    BEGIN
        PRINT N'Người mượn có hóa đơn chưa thanh toán. Không thể đặt mượn mới.'
        ROLLBACK TRANSACTION;  -- Hủy bỏ giao dịch nếu điều kiện không thỏa mãn
        RETURN;
    END

    -- Nếu không có lỗi, thực hiện chèn dữ liệu mới vào bảng DATMUON
    INSERT INTO DATMUON (ID_NguoiMuon, TenNguoiMuon, DonVi, SDT, Email, ID_PhP, Ten_PhP, CoSo, TenDvuKem, ID_Ca, NgayDky, NgaySD, status)
    SELECT ID_NguoiMuon, TenNguoiMuon, DonVi, SDT, Email, ID_PhP, Ten_PhP, CoSo, TenDvuKem, ID_Ca, NgayDky, NgaySD, status
    FROM INSERTED;

    PRINT N'Dữ liệu đã được chèn thành công vào bảng DATMUON.';
END;
-- THỬ
EXEC DATPHONG '2256210055','Ha Anh Tuan', 'TVTTH', '0939556889', 'TTT@gmail.com', 'Phong hop - PH101', 'TD', 'Ban backdrop,Treo bandroll',3, '2024/09/03'
---TH2: CÓ HOÁ ĐƠN CHƯA THANH TOÁN (THỰC HIỆN PROC DUYỆT PHÒNG VỚI ĐƠN DATMUON Ở EXEC DATPHONG VÍ DỤ, SAU ĐÓ CẬP NHẬT CHECK IN, CHECK OUT (CHƯA THANH TOÁN) RỒI QUAY LẠI)
EXEC DATPHONG '2445678901','Tran Thi Dieu', 'Xa hoi hoc', '0948901234', '2445678901@hcmussh.edu.vn', 'A-202', 'TD', 'Ban backdrop,Treo bandroll',3, '2024/12/03'

---Trigger: trg_ValidateDates
CREATE TRIGGER trg_ValidateDates
ON DATMUON
AFTER INSERT, UPDATE
AS
BEGIN
    -- Kiểm tra điều kiện ngày đăng ký phải trước ngày sử dụng
    IF EXISTS (
        SELECT 1
        FROM INSERTED
        WHERE NgayDky >= NgaySD
    )
    BEGIN
        PRINT N'Ngày đăng ký phải trước ngày sử dụng';
        ROLLBACK TRANSACTION;
    END
END;
-- THỬ
EXEC DATPHONG '2256210047','Tran Avo', 'TVTTH', '0939556889', 'TTT@gmail.com', 'A-202', 'TD', 'Ban backdrop,Treo bandroll',3, '2023/09/03'

-- Trigger: trg_ValidateContactInfo
CREATE TRIGGER trg_ValidateContactInfo
ON NGUOIMUON
INSTEAD OF INSERT, UPDATE
AS
BEGIN
    DECLARE @SDT NCHAR(10);
    DECLARE @Email NVARCHAR(255);
    DECLARE @ID NVARCHAR(50);

    -- Lấy giá trị từ INSERTED để kiểm tra
    SELECT @SDT = SDT, @Email = Email, @ID = MaNguoiMuon
    FROM INSERTED;

    -- Kiểm tra độ dài và định dạng số điện thoại
    IF LEN(@SDT) != 10 OR PATINDEX('%[^0-9]%', @SDT) > 0
    BEGIN
        PRINT N'Số điện thoại không hợp lệ.';
        ROLLBACK TRANSACTION;  -- Hủy bỏ giao dịch nếu điều kiện không thỏa mãn
        RETURN;
    END

    -- Kiểm tra định dạng email hợp lệ
    IF @Email NOT LIKE '%_@__%.__%'
    BEGIN
        PRINT N'Email không hợp lệ.';
        ROLLBACK TRANSACTION;  -- Hủy bỏ giao dịch nếu điều kiện không thỏa mãn
        RETURN;
    END

    -- Thực hiện thao tác thêm hoặc cập nhật bình thường
    IF NOT EXISTS (SELECT 1 FROM NGUOIMUON WHERE MaNguoiMuon = @ID)
    BEGIN
        INSERT INTO NGUOIMUON (MaNguoiMuon, Ten, DonVi, SDT, Email)
        SELECT MaNguoiMuon, Ten, DonVi, SDT, Email
        FROM INSERTED;
    END
    ELSE
    BEGIN
        UPDATE NGUOIMUON
        SET Ten = i.Ten,
            DonVi = i.DonVi,
            SDT = i.SDT,
            Email = i.Email
        FROM INSERTED i
        WHERE NGUOIMUON.MaNguoiMuon = i.MaNguoiMuon;
    END
END;
EXEC DATPHONG '2256210078','Tran Avo', 'TVTTH', '0939500589', 'TTmail.com', 'A-401', 'TD', 'Karaoke',3, '2027/08/03'
 
 -- Trigger: trg_CheckBookingDate

CREATE TRIGGER trg_CheckBookingDate
ON HOADON
INSTEAD OF INSERT
AS
BEGIN
    DECLARE @ID_DatMuon INT
    DECLARE @NgaySD DATETIME
    DECLARE @CheckIn DATETIME
	DECLARE @CaID int
	DECLARE @TGBDCa TIME
	DECLARE @TGKTCa TIME
	declare @status nvarchar(50)

    -- Lấy giá trị từ INSERTED để kiểm tra
    SELECT @ID_DatMuon = ID_DatMuon, @CheckIn = CheckIn
    FROM INSERTED

    -- Lấy giá trị NgaySD từ bảng DATMUON
    SELECT @NgaySD = NgaySD, @CaID=ID_Ca
    FROM DATMUON
    WHERE ID_DatMuon = @ID_DatMuon
	---Lấy giá trị tgian bắt đầu và Ketthuc ca
	select @TGBDCa=TGBatDau, @TGKTCa=TGKetThuc
	from CAMUON
	WHERE MaCa=@CaID
    -- Kiểm tra điều kiện
    IF @NgaySD <> CAST(@CheckIn AS DATE) 
	OR (@NgaySD = CAST(@CheckIn AS DATE) and (CAST(@CheckIn AS TIME) not between @TGBDCa AND @TGKTCa))
    BEGIN
        PRINT N'Thời gian sử dụng khác thời gian check-in hoặc chưa được duyệt. Không thể thêm hoặc cập nhật bản ghi.'
        ROLLBACK TRANSACTION;  -- Hủy bỏ giao dịch nếu điều kiện không thỏa mãn
    END
    ELSE
    BEGIN
        -- Thực hiện thao tác thêm bình thường
        INSERT INTO HOADON (ID_DatMuon, TenNguoiMuon, Ten_PhP, GiaPhong, TenDvuKem, GiaDvuKem, CheckIn)
        SELECT ID_DatMuon, TenNguoiMuon, Ten_PhP, GiaPhong, TenDvuKem, GiaDvuKem, CheckIn
        FROM INSERTED
    END
END;
-- THỬ
select * from hoadon
EXEC CHECKIN 32

-- Trigger: trg_BeforeInsertThanhToan

CREATE TRIGGER trg_BeforeInsertThanhToan
ON THANHTOAN
INSTEAD OF INSERT
AS
BEGIN
    DECLARE @ID_HoaDon INT;
    DECLARE @TinhTrangThanhToan NVARCHAR(50);

    -- Lấy giá trị từ bảng INSERTED để kiểm tra
    SELECT @ID_HoaDon = ID_HoaDon
    FROM INSERTED;

    -- Kiểm tra nếu hóa đơn tồn tại và chưa được thanh toán
    SELECT @TinhTrangThanhToan = TinhTrangThanhToan
    FROM HOADON
    WHERE ID_HoaDon = @ID_HoaDon;

    IF @TinhTrangThanhToan IS NULL
    BEGIN
        PRINT N'ID_HoaDon không tồn tại.';
        ROLLBACK TRANSACTION;
    END
    ELSE IF @TinhTrangThanhToan = 'Da thanh toan'
    BEGIN
        PRINT N'Hóa đơn đã được thanh toán.';
        ROLLBACK TRANSACTION;
    END
    ELSE
    BEGIN
        -- Thực hiện thao tác thêm bình thường
        INSERT INTO THANHTOAN (ID_HoaDon, TenNguoiMuon, HinhThucThanhToan)
        SELECT ID_HoaDon, TenNguoiMuon, HinhThucThanhToan
        FROM INSERTED;
    END
END;
--THỬ
EXEC CAPNHATTHANHTOAN 18, 'TT'

-- Trigger: trg_CheckAdminBeforeApproval
CREATE TRIGGER trg_CheckAdminBeforeApproval
ON DATMUON
INSTEAD OF UPDATE
AS
BEGIN
    DECLARE @MaNQL NVARCHAR(50);
    DECLARE @MaMuon INT;
    DECLARE @NewStatus NVARCHAR(50);

    -- Lấy giá trị từ INSERTED để kiểm tra
    SELECT @MaNQL = ID_NguoiQL, @MaMuon = ID_DatMuon, @NewStatus = status
    FROM INSERTED;

    -- Kiểm tra mã quản lý
    IF NOT EXISTS (SELECT 1 FROM NGUOIQL WHERE MaNguoiQL = @MaNQL)
    BEGIN
        PRINT N'Bạn không phải là admins';
        ROLLBACK TRANSACTION;  -- Hủy bỏ giao dịch nếu điều kiện không thỏa mãn
    END
    ELSE
    BEGIN
        -- Thực hiện cập nhật nếu mã quản lý hợp lệ
        UPDATE DATMUON
        SET ID_NguoiQL = @MaNQL, status = @NewStatus
        WHERE ID_DatMuon = @MaMuon;
    END
END;
-- THỬ
EXEC DUYETPHONG 13, 'No', 29
EXEC DUYETPHONG 1, 'No', 299

-- Trigger: trg_OnlyAllowValidServices
CREATE TRIGGER trg_OnlyAllowValidServices
ON DATMUON
after INSERT
AS
BEGIN
    -- Kiểm tra dịch vụ kèm chỉ cho phép thêm những dịch vụ có trong bảng dichvukem
    IF EXISTS (
        SELECT 1
        FROM inserted i
        LEFT JOIN dichvukem d ON i.TenDvuKem LIKE '%' + d.TenDVu + '%'
        WHERE d.TenDVu IS NULL
    )
    BEGIN
        PRINT N'Không thể thêm dịch vụ kèm không hợp lệ.';
        ROLLBACK TRANSACTION; -- Hủy bỏ giao dịch nếu điều kiện không thỏa mãn
        RETURN;
    END

    -- Nếu không có lỗi, thực hiện chèn dữ liệu mới vào bảng DATMUON
    INSERT INTO DATMUON (ID_NguoiMuon, TenNguoiMuon, DonVi, SDT, Email, ID_PhP, Ten_PhP, CoSo, TenDvuKem, ID_Ca, NgayDky, NgaySD, status)
    SELECT ID_NguoiMuon, TenNguoiMuon, DonVi, SDT, Email, ID_PhP, Ten_PhP, CoSo, TenDvuKem, ID_Ca, NgayDky, NgaySD, status
    FROM INSERTED;

    PRINT N'Dữ liệu đã được chèn thành công vào bảng DATMUON.';
END;
-- THỬ
EXEC DATPHONG '2256210089','Tran Nguyen Nhu Tam', 'TVTTH', '0939556889', 'TTT@gmail.com', 'A-401', 'TD', 'Karaoke',3, '2027/09/03'

-- Trigger: trg_PreventDeleteRoom
CREATE TRIGGER trg_PreventDeleteRoom
ON CHITIETPHONG
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MaPhongDaXoa INT;

    -- Lấy ID của phòng đang bị xóa
    SELECT @MaPhongDaXoa = MaPhong FROM deleted;

    -- Bắt đầu giao dịch
    BEGIN TRANSACTION;

    -- Kiểm tra xem phòng có đang được đặt mượn hoặc đã check-in
    IF EXISTS (
        SELECT 1 
        FROM DATMUON 
        WHERE ID_PhP = @MaPhongDaXoa 
          AND (status IN ('Da duyet', 'Da CheckIn'))
    )
    BEGIN
        -- Rollback transaction nếu phòng đang được đặt mượn hoặc đã check-in
        ROLLBACK TRANSACTION;
        Print(N'Không thể xoá phòng đang được đặt mượn hoặc đã check-in.');
        RETURN;
    END

    -- Nếu phòng không bị ràng buộc bởi điều kiện trên, cho phép xóa
    DELETE FROM CHITIETPHONG
    WHERE MaPhong = @MaPhongDaXoa;

    -- Commit transaction nếu xóa thành công
    COMMIT TRANSACTION;
END;
-- THỬ
EXEC QUANLYPHONG 'DELETE', 'Hoi truong Tong Hop', null, null,null,null,3

---***---
----Tạo LOGIN và USER của SINHVIEN----
CREATE LOGIN [2103456789] WITH PASSWORD = 'SV'

CREATE USER [2103456789] FOR LOGIN [2103456789];

CREATE LOGIN [2145678901] WITH PASSWORD = 'SV01'

CREATE USER [2145678901] FOR LOGIN [2145678901];

CREATE LOGIN [2256210048] WITH PASSWORD = 'SV02'

CREATE USER [2256210048] FOR LOGIN [2256210048];

----Tạo LOGIN và USER của QUANLY----
CREATE LOGIN [QL01] WITH PASSWORD = 'QL01'

CREATE USER [QL1] FOR LOGIN [QL01];

CREATE LOGIN [QL02] WITH PASSWORD= 'QL02'

CREATE USER [QL2] FOR LOGIN [QL02];

-- Cấp quyền SELECT, INSERT và UPDATE  người dùng SINHVIEN----

GRANT SELECT,INSERT,UPDATE ON NGUOIMUON TO QL1;
GRANT SELECT,INSERT,UPDATE ON DICHVUKEM TO QL1;
GRANT SELECT,INSERT,UPDATE ON TKB TO QL1;
GRANT SELECT,INSERT,UPDATE ON CHITIETPHONG TO QL1;

GRANT SELECT,INSERT,UPDATE ON NGUOIMUON TO QL2;
GRANT SELECT,INSERT,UPDATE ON DICHVUKEM TO QL2;
GRANT SELECT,INSERT,UPDATE ON TKB TO QL2;
GRANT SELECT,INSERT,UPDATE ON CHITIETPHONG TO QL2;


-- Cấp quyền SELECT, INSERT và UPDATE  người dùng SINHVIEN----
--Cấp quyền SV xem thông tin CHITIETPHONG--
GRANT SELECT ON CHITIETPHONG TO [2103456789];
GRANT SELECT ON CHITIETPHONG TO [2145678901];
GRANT SELECT ON CHITIETPHONG TO [2256210048];
----Cho phép người mượn xem danh sách DICHVUKEM---
GRANT SELECT ON DICHVUKEM TO [2103456789];
GRANT SELECT ON DICHVUKEM TO [2145678901];
GRANT SELECT ON DICHVUKEM TO [2256210048];
----Cho phép người mượn xem TKB---
GRANT SELECT ON TKB TO [2103456789];
GRANT SELECT ON TKB TO [2145678901];
GRANT SELECT ON TKB TO [2256210048];
----Cấp quyền SV chỉ xem thông tin NGUOIMUON của chính mình--
DROP VIEW NguoiMuon_Personal

CREATE VIEW NguoiMuon_Personal AS
(
    SELECT * 
    FROM NGUOIMUON 
    WHERE CAST(MaNguoiMuon AS BIGINT) = CAST(SYSTEM_USER AS BIGINT)
)
--Cấp quyền SELECT cho view NguoiMuon_Personal cho người dùng SINHVIEN--Nhớ đổi user - chọn database----
GRANT SELECT ON NguoiMuon_Personal TO [2103456789];
GRANT SELECT ON NguoiMuon_Personal TO [2145678901];
GRANT SELECT ON NguoiMuon_Personal TO [2256210048];

----Cấp quyền SV chỉ xem lịch sử DATMUON của chính mình--Đăng nhập -> Query nhập vào 
DROP VIEW NguoiMuon_Dat

CREATE VIEW NguoiMuon_Dat AS
(
    SELECT * 
    FROM DATMUON 
    WHERE CAST(ID_NguoiMuon AS BIGINT) = CAST(SYSTEM_USER AS BIGINT)
)
--Cho phép người mượn xem lịch sử DATMUON của chính mình---
GRANT SELECT ON NguoiMuon_Dat TO [2103456789];
GRANT SELECT ON NguoiMuon_Dat TO [2145678901];
GRANT SELECT ON NguoiMuon_Dat TO [2256210048];
----
CREATE VIEW LsuDatMuon AS
(
    SELECT * 
    FROM exec XemLichSuDatPhong
    WHERE CAST(ID_NguoiMuon AS BIGINT) = CAST(SYSTEM_USER AS BIGINT)
)
-- PHÂN QUYỀN PROCEDURE
GRANT EXEC ON DUYETPHONG TO QL1
GRANT EXEC ON XemDonMuonPhongQuaHan TO QL1
GRANT EXEC ON QUANLYPHONG  TO QL1
GRANT EXEC ON GUITHONGBAONHAC TO QL1
GRANT EXEC ON XEMBAOCAO TO QL1
