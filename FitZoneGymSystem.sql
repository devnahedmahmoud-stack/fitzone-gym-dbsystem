Create DataBase FitZoneGymSystem
go
Use FitZoneGymSystem;

--===========================================================
Create Table Trainers (
ID Int Not NULL Identity(1,1),
TrainerName NVarchar(150) Not Null,
Specialty NVarchar(200) Not Null,
Constraint PK_Trainers Primary Key (ID)
)
go

Create Table Classes (
ID Int Not NULL Identity(1,1),
ClassName NVarchar(500) Not Null,
Duration Int Not Null Default 120,
MaxCapacity Int Not Null Default 30,
TrainerID Int Not Null,
Constraint PK_Classes Primary Key (ID),
Constraint FK_Classes_Trainers Foreign Key (TrainerID)
References Trainers(ID),
Constraint CK_Classes_MaxCapacity Check (MaxCapacity>0 and MaxCapacity<=30)
)
go

Create Table Members (
ID Int Not NULL Identity(1,1),
MemberName NVarchar(150) Not Null,
Email NVarchar(200) Not Null,
MembershipType NVarchar(200) Not Null,
Constraint PK_Members Primary Key (ID),
Constraint UQ_Members_Email Unique (Email),
Constraint CK_Members_MembershipType Check (MembershipType in ('Basic','Premium','VIP'))
)
go

Create Table Bookings (
ID Int Not NULL Identity(1,1),
BookStatus NVarchar(150) Not Null,
MemberID Int Not Null,
ClassID Int Not Null,
Constraint PK_Bookings Primary Key (ID),
Constraint FK_Bookings_Members Foreign Key (MemberID)
References Members(ID),
Constraint FK_Bookings_Classes Foreign Key (ClassID)
References Classes(ID),
Constraint CK_Bookings_BookStatus Check (BookStatus in ('Confirmed','Cancelled'))
)
go

Create Table Payments(
ID Int Not NULL Identity(1,1),
Amount Decimal (6,2) Not NULL,
Method NVarchar(150) Not Null,
BookID Int Not Null,
Constraint PK_Payments Primary Key (ID),
Constraint FK_Payments_Bookings Foreign Key (BookID)
References Bookings(ID),
Constraint CK_Payments_Amount Check (Amount>0),
Constraint CK_Payments_Method Check (Method in ('Cash','Card','Transfer'))
)
go
--===========================================================================
--insert data to Members
Insert Into Members(MemberName,Email,MembershipType)
Values ('Sarah Jenkins','sarah.jenkins@example.com','Basic'),
('Marcus Vance','marcus.vance@example.com','Premium'),
('Elena Rostova','elena.rostova@example.com','Basic'),
('Emma Stone','emma.stone@example.com','Premium'),
('Hally Barry','hally.barry@example.com','VIP'),
('Brad Pitt','brad.pitt@example.com','VIP'),
('Robert Downey','robert.downey@example.com','Basic'),
('Jinnefer Lopez','jinnefer.lopez@example.com','VIP'),
('David Chen','david.chen@example.com','Premium'),
('Amara Okonjo','amara.okonjo@example.com','VIP')


--insert data to Trainers
Insert Into Trainers(TrainerName,Specialty)
Values ('Jody Andrson','Yoga'),
('Anna Jhonson','Zumba'),
('James William','Strength Training'),
('Jessica Taylor','Cardio'),
('Lucas Daniel','Boxing')


--insert into Classes
Insert Into Classes(ClassName,Duration,MaxCapacity,TrainerID)
Values ('Yoga',60,20,1),
('Zumba',90,30,2),
('Strength Training',120,25,3),
('Cardio',90,20,4),
('Boxing',60,25,5)


--insert into Bookings 
Insert Into Bookings (BookStatus,MemberID,ClassID)
Values ('Confirmed',1,1),
('Confirmed',1,2),
('Cancelled',2,3),
('Confirmed',3,4),
('Cancelled',4,1),
('Confirmed',4,5),
('Cancelled',5,3),
('Confirmed',5,2),
('Confirmed',6,5),
('Cancelled',6,1),
('Confirmed',7,3),
('Cancelled',8,2),
('Confirmed',9,3),
('Confirmed',9,4),
('Confirmed',10,3),
('Confirmed',10,5)


--insert into Payments
Insert into Payments (Amount,Method,BookID)
Values (1000.00,'Cash',1),
(800.00,'Card',2),
(500.00,'Cash',4),
(1000.00,'Cash',6),
(800.00,'Cash',8),
(1000.00,'Card',9),
(700.00,'Cash',11),
(700.00,'Transfer',13),
(500.00,'Transfer',14),
(700.00,'Card',15),
(1000.00,'Card',16)

--=========================================================================================================
--UPDATE with a WHERE clause (e.g. a member upgrading their membership type), 
--and one DELETE with a WHERE clause (e.g. a cancelled booking).
Update Members Set MembershipType='Basic' Where ID=5
go
Delete From Bookings Where ID=5 --Cancelled 

--========================================================================================================
--4. Reports (JOINs + aggregation)
--A report joining 3 or more tables   e.g. every booking showing the member's name, the class
--name, and the trainer who runs it.

Select m.MemberName As [Member Name],
c.ClassName as [Class Name],
t.TrainerName As [Trainer Name],
b.BookStatus As [Book Status]
From Bookings b
Inner join Members m 
on b.MemberID=m.ID
Inner Join Classes c
on b.ClassID=c.ID
Inner Join Trainers t
on c.TrainerID =t.ID
go


--A GROUP BY report with a HAVING clause   e.g. classes with more than a certain number of
--confirmed bookings.
Select Count(b.ID) as [Class Confirmed Bookings Count],c.ClassName as [Class Name]
From Bookings b
Inner Join Classes c
on b.ClassID=c.ID
Where BookStatus='Confirmed'
Group by c.ClassName
Having COUNT(b.ID)>2
go

--===========================================================================================================
--5. A subquery
--Find every member who has never booked a single class. (Think about why NOT EXISTS is the
--safe way to write this, not NOT IN.)

--NOT EXISTS is the safe way to write this, not NOT IN 
--Not IN used when ensure range of values don't have null values and subquery may return null values which evaluted as unknown
--so NOT EXISTS is the safe way to write

Select m.MemberName as [Member Name]
From Members m
Where Not Exists (Select 1 From Bookings b where b.MemberID=m.ID )
go

--================================================================================================================
--6. A view
--Create a read-only view   something like ActiveMembersSummary   that gives a quick snapshot of
--each member and their total number of confirmed bookings, without anyone needing to know the
--underlying JOIN to get it.

Create View ActiveMembersSummary AS
Select m.MemberName as [Member Name],Count(b.ID) as [Confirmed Bookings Total Number]
From Members m
Inner Join Bookings b
on m.ID=b.MemberID
Where b.BookStatus='Confirmed'
Group by m.MemberName
go

Select * from ActiveMembersSummary
go

--====================================================================================================================
--7. A stored procedure, wrapped in a transaction
--Write a procedure that books a member into a class   but it has to actually enforce the business
--rule: check the class isn't already at capacity BEFORE inserting the booking, and do the whole
--thing as a single transaction so a failed capacity check never leaves a half-done booking behind.

Create Procedure usp_ClassBook 
@BookStatus Nvarchar(150),@MemberID int,@ClassID int

As
Begin Try
	Declare @MaxCapacity int
	Select @MaxCapacity=MaxCapacity From Classes c where c.ID=@ClassID

	Begin Transaction

	if ((Select Count(b.ID) As [Class Total Bookings]
	From Bookings b 
	Where b.ClassID=@ClassID and b.BookStatus='Confirmed')>=@MaxCapacity)
	Begin
		RollBack Transaction
		Print 'Class Capacity reached to its maximum capacity :'+Cast(@MaxCapacity as varchar(3))
		Return 
	End

	Insert Into  Bookings (BookStatus,MemberID,ClassID)
	Values (@BookStatus,@MemberID,@ClassID)
	Commit Transaction
End Try
Begin Catch
	IF(@@TRANCOUNT>0)
	Begin
		RollBack Transaction	
		Print 'Error Line #'+Cast(ERROR_LINE() as varchar(10))+
		' Error Message: '+ERROR_MESSAGE();
	End
End catch
go

Exec usp_ClassBook 
@BookStatus ='Confirmed',@MemberID =9,@ClassID =4
go

Exec usp_ClassBook 
@BookStatus ='Confirmed',@MemberID =2,@ClassID =4
go

Exec usp_ClassBook 
@BookStatus ='Confirmed',@MemberID =1,@ClassID =3
go

Exec usp_ClassBook 
@BookStatus ='Confirmed',@MemberID =1,@ClassID =4
go

Exec usp_ClassBook 
@BookStatus ='Confirmed',@MemberID =1,@ClassID =5
go

Exec usp_ClassBook 
@BookStatus ='Confirmed',@MemberID =6,@ClassID =2
go

Exec usp_ClassBook 
@BookStatus ='Confirmed',@MemberID =6,@ClassID =3
go

Exec usp_ClassBook 
@BookStatus ='Confirmed',@MemberID =6,@ClassID =4
go

Exec usp_ClassBook 
@BookStatus ='Confirmed',@MemberID =4,@ClassID =1
go

Exec usp_ClassBook 
@BookStatus ='Confirmed',@MemberID =4,@ClassID =2
go

Exec usp_ClassBook 
@BookStatus ='Confirmed',@MemberID =4,@ClassID =3
go

Exec usp_ClassBook 
@BookStatus ='Confirmed',@MemberID =4,@ClassID =4
go

--======================================================================================================
--Bonus (optional   hard, not impossible)
--Find the member(s) who have booked at least one class with every single trainer at the gym  
--not just a lot of trainers, literally all of them. This is a genuinely tricky query. You already
--have everything you need from Session 08's NOT EXISTS pattern   think about it as "find a member
--where there is NOT a trainer they've never booked."

Select m.MemberName 
From Members m
Where Not Exists
(
	Select t.ID
	From Trainers t
	Where Not Exists 
	(
		Select 1 
		From Classes c 
		Inner Join Bookings b 
		on c.ID =b.ClassID 
		Where c.TrainerID =t.ID
		And b.MemberID=m.ID
		And b.BookStatus='Confirmed'
	)
)
go

--=========================================================================================================

--Select * from Trainers
--Select * from Classes
--Select * from Members
--Select * from Bookings
--Select * from Payments


--drop table Payments
--drop table Bookings
--drop table Members
--drop table Classes
--drop table Trainers

--drop view ActiveMembersSummary
--drop procedure usp_ClassBook