from fastapi import FastAPI, Depends, HTTPException, UploadFile, Form, File
from sqlalchemy import (
    create_engine,
    Column,
    Integer,
    String,
    TIMESTAMP,
    ForeignKey,
    DECIMAL,
    Text,
)
from sqlalchemy.orm import sessionmaker, relationship, declarative_base, Session
from pydantic import BaseModel, field_validator
import hashlib
import requests
from datetime import datetime
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import time
import shutil
import os

# Database configuration
DATABASE_URL = "mysql+pymysql://root:@localhost/paquexpress_db"
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(bind=engine, autocommit=False, autoflush=False)
Base = declarative_base()

app = FastAPI(title="Sistema de Entregas Paquexpress")

# Montar carpeta de uploads
os.makedirs("uploads", exist_ok=True)
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Database Models
class User(Base):
    __tablename__ = "users"
    
    user_id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    full_name = Column(String(100))
    role = Column(String(20), default="agent", nullable=False)
    created_at = Column(TIMESTAMP, default=datetime.utcnow)
    
    deliveries = relationship("Delivery", back_populates="agent")


class Package(Base):
    __tablename__ = "packages"
    
    package_id = Column(Integer, primary_key=True, index=True)
    tracking_number = Column(String(50), unique=True, nullable=False)
    destination_address = Column(String(255), nullable=False)
    recipient_name = Column(String(100), nullable=False)
    status = Column(String(20), default="pending", nullable=False)
    created_at = Column(TIMESTAMP, default=datetime.utcnow)
    
    deliveries = relationship("Delivery", back_populates="package")


class Delivery(Base):
    __tablename__ = "deliveries"
    
    delivery_id = Column(Integer, primary_key=True, index=True)
    package_id = Column(Integer, ForeignKey("packages.package_id"), nullable=False)
    agent_id = Column(Integer, ForeignKey("users.user_id"), nullable=False)
    latitude = Column(DECIMAL(10, 8), nullable=False)
    longitude = Column(DECIMAL(11, 8), nullable=False)
    address = Column(String(255))
    photo_path = Column(String(255))
    notes = Column(Text)
    delivered_at = Column(TIMESTAMP, default=datetime.utcnow)
    
    package = relationship("Package", back_populates="deliveries")
    agent = relationship("User", back_populates="deliveries")


Base.metadata.create_all(bind=engine)


# Pydantic Models
class RegisterModel(BaseModel):
    username: str
    password: str
    full_name: str
    role: str = "agent"
    
    @field_validator('username')
    @classmethod
    def validate_username(cls, v):
        if len(v) < 3:
            raise ValueError('Username must be at least 3 characters')
        return v
    
    @field_validator('password')
    @classmethod
    def validate_password(cls, v):
        if len(v) < 6:
            raise ValueError('Password must be at least 6 characters')
        return v


class LoginModel(BaseModel):
    username: str
    password: str


class LoginResponse(BaseModel):
    message: str
    user_id: int
    username: str
    full_name: str
    role: str


class PackageModel(BaseModel):
    tracking_number: str
    destination_address: str
    recipient_name: str


class PackageResponse(BaseModel):
    package_id: int
    tracking_number: str
    destination_address: str
    recipient_name: str
    status: str
    created_at: str


class DeliveryResponse(BaseModel):
    delivery_id: int
    package_id: int
    tracking_number: str
    agent_name: str
    latitude: float
    longitude: float
    address: str
    photo_path: str
    delivered_at: str


# Dependency
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# Helper Functions
def md5_hash(password: str) -> str:
    return hashlib.md5(password.encode()).hexdigest()


def get_address_from_coords(lat: float, lon: float) -> str:
    try:
        url = "https://nominatim.openstreetmap.org/reverse"
        headers = {"User-Agent": "PaquexpressApp/1.0"}
        params = {
            "format": "json",
            "lat": lat,
            "lon": lon,
            "zoom": 18,
            "addressdetails": 1
        }
        
        time.sleep(1)
        response = requests.get(url, params=params, headers=headers, timeout=5)
        
        if response.status_code == 200:
            result = response.json()
            address = result.get("display_name", "Dirección no encontrada")
        else:
            address = "Dirección no encontrada"
            
        return address
    except Exception as e:
        print(f"Error fetching address: {str(e)}")
        return "Error al obtener dirección"


def get_user_by_id(db: Session, user_id: int):
    user = db.query(User).filter(User.user_id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    return user


# API Endpoints - AUTENTICACIÓN
@app.post("/register")
def register(user_data: RegisterModel, db: Session = Depends(get_db)):
    existing_user = db.query(User).filter(User.username == user_data.username).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="El nombre de usuario ya existe")
    
    hashed_pw = md5_hash(user_data.password)
    new_user = User(
        username=user_data.username,
        password_hash=hashed_pw,
        full_name=user_data.full_name,
        role=user_data.role
    )
    
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    return {
        "message": "Usuario registrado exitosamente",
        "user_id": new_user.user_id,
        "username": new_user.username,
        "role": new_user.role
    }


@app.post("/login", response_model=LoginResponse)
def login(data: LoginModel, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.username == data.username).first()
    
    if not user or user.password_hash != md5_hash(data.password):
        raise HTTPException(status_code=401, detail="Credenciales inválidas")
    
    return LoginResponse(
        message="Inicio de sesión exitoso",
        user_id=user.user_id,
        username=user.username,
        full_name=user.full_name,
        role=user.role
    )


# API Endpoints - PAQUETES
@app.post("/packages")
def create_package(
    package: PackageModel, 
    requesting_user_id: int,
    db: Session = Depends(get_db)
):
    """Crear un nuevo paquete (solo admin)"""
    user = get_user_by_id(db, requesting_user_id)
    
    if user.role != "admin":
        raise HTTPException(
            status_code=403,
            detail="No tienes permisos para crear paquetes"
        )
    
    existing = db.query(Package).filter(
        Package.tracking_number == package.tracking_number
    ).first()
    
    if existing:
        raise HTTPException(status_code=400, detail="El número de rastreo ya existe")
    
    new_package = Package(
        tracking_number=package.tracking_number,
        destination_address=package.destination_address,
        recipient_name=package.recipient_name
    )
    
    db.add(new_package)
    db.commit()
    db.refresh(new_package)
    
    return {
        "message": "Paquete creado exitosamente",
        "package_id": new_package.package_id,
        "tracking_number": new_package.tracking_number
    }


@app.get("/packages/all", response_model=list[PackageResponse])
def get_all_packages(requesting_user_id: int, db: Session = Depends(get_db)):
    """Obtener todos los paquetes (solo admin)"""
    user = get_user_by_id(db, requesting_user_id)
    
    if user.role != "admin":
        raise HTTPException(
            status_code=403,
            detail="No tienes permisos para ver todos los paquetes"
        )
    
    packages = db.query(Package).order_by(Package.created_at.desc()).all()
    
    return [
        PackageResponse(
            package_id=p.package_id,
            tracking_number=p.tracking_number,
            destination_address=p.destination_address,
            recipient_name=p.recipient_name,
            status=p.status,
            created_at=p.created_at.isoformat()
        )
        for p in packages
    ]


@app.delete("/packages/{package_id}")
def delete_package(
    package_id: int,
    requesting_user_id: int,
    db: Session = Depends(get_db)
):
    """Eliminar un paquete (solo admin y solo si está pendiente)"""
    user = get_user_by_id(db, requesting_user_id)
    
    if user.role != "admin":
        raise HTTPException(
            status_code=403,
            detail="No tienes permisos para eliminar paquetes"
        )
    
    package = db.query(Package).filter(Package.package_id == package_id).first()
    
    if not package:
        raise HTTPException(status_code=404, detail="Paquete no encontrado")
    
    if package.status != "pending":
        raise HTTPException(
            status_code=400,
            detail="No se puede eliminar un paquete ya entregado"
        )
    
    db.delete(package)
    db.commit()
    
    return {"message": "Paquete eliminado exitosamente"}


@app.get("/packages/pending", response_model=list[PackageResponse])
def get_pending_packages(db: Session = Depends(get_db)):
    """Obtener paquetes pendientes de entrega"""
    packages = db.query(Package).filter(Package.status == "pending").all()
    
    return [
        PackageResponse(
            package_id=p.package_id,
            tracking_number=p.tracking_number,
            destination_address=p.destination_address,
            recipient_name=p.recipient_name,
            status=p.status,
            created_at=p.created_at.isoformat()
        )
        for p in packages
    ]


@app.get("/packages/{package_id}", response_model=PackageResponse)
def get_package(package_id: int, db: Session = Depends(get_db)):
    """Obtener información de un paquete específico"""
    package = db.query(Package).filter(Package.package_id == package_id).first()
    
    if not package:
        raise HTTPException(status_code=404, detail="Paquete no encontrado")
    
    return PackageResponse(
        package_id=package.package_id,
        tracking_number=package.tracking_number,
        destination_address=package.destination_address,
        recipient_name=package.recipient_name,
        status=package.status,
        created_at=package.created_at.isoformat()
    )


# API Endpoints - ENTREGAS
@app.post("/deliveries")
async def register_delivery(
    package_id: int = Form(...),
    agent_id: int = Form(...),
    latitude: float = Form(...),
    longitude: float = Form(...),
    notes: str = Form(""),
    file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    """Registrar una entrega con foto y ubicación"""
    
    # Verificar que el paquete existe y está pendiente
    package = db.query(Package).filter(Package.package_id == package_id).first()
    if not package:
        raise HTTPException(status_code=404, detail="Paquete no encontrado")
    
    if package.status == "delivered":
        raise HTTPException(status_code=400, detail="El paquete ya fue entregado")
    
    # Verificar que el agente existe
    agent = get_user_by_id(db, agent_id)
    
    try:
        # Guardar la foto
        photo_path = f"uploads/{file.filename}"
        with open(photo_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
        
        # Obtener dirección desde coordenadas
        address = get_address_from_coords(latitude, longitude)
        
        # Crear registro de entrega
        delivery = Delivery(
            package_id=package_id,
            agent_id=agent_id,
            latitude=latitude,
            longitude=longitude,
            address=address,
            photo_path=photo_path,
            notes=notes
        )
        
        # Actualizar estado del paquete
        package.status = "delivered"
        
        db.add(delivery)
        db.commit()
        db.refresh(delivery)
        
        return {
            "message": "Entrega registrada exitosamente",
            "delivery_id": delivery.delivery_id,
            "address": address,
            "photo_path": photo_path
        }
        
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Error al registrar entrega: {str(e)}")


@app.get("/deliveries/agent/{agent_id}", response_model=list[DeliveryResponse])
def get_agent_deliveries(agent_id: int, db: Session = Depends(get_db)):
    """Obtener historial de entregas de un agente"""
    agent = get_user_by_id(db, agent_id)
    
    deliveries = db.query(Delivery).filter(
        Delivery.agent_id == agent_id
    ).order_by(Delivery.delivered_at.desc()).all()
    
    return [
        DeliveryResponse(
            delivery_id=d.delivery_id,
            package_id=d.package_id,
            tracking_number=d.package.tracking_number,
            agent_name=agent.full_name,
            latitude=float(d.latitude),
            longitude=float(d.longitude),
            address=d.address,
            photo_path=d.photo_path,
            delivered_at=d.delivered_at.isoformat()
        )
        for d in deliveries
    ]


@app.get("/deliveries/all", response_model=list[DeliveryResponse])
def get_all_deliveries(requesting_user_id: int, db: Session = Depends(get_db)):
    """Obtener todas las entregas (solo para admins)"""
    user = get_user_by_id(db, requesting_user_id)
    
    if user.role != "admin":
        raise HTTPException(
            status_code=403,
            detail="No tienes permisos para ver todas las entregas"
        )
    
    deliveries = db.query(Delivery).order_by(Delivery.delivered_at.desc()).all()
    
    return [
        DeliveryResponse(
            delivery_id=d.delivery_id,
            package_id=d.package_id,
            tracking_number=d.package.tracking_number,
            agent_name=d.agent.full_name,
            latitude=float(d.latitude),
            longitude=float(d.longitude),
            address=d.address,
            photo_path=d.photo_path,
            delivered_at=d.delivered_at.isoformat()
        )
        for d in deliveries
    ]


@app.get("/health")
def health_check():
    return {"status": "healthy", "timestamp": datetime.utcnow().isoformat()}