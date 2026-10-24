# ERD — قاعدة بيانات تطبيق العقارات

مولَّد تلقائياً من `prisma/schema.prisma` (بيتعرض مباشرة على GitHub / VS Code بإضافة Mermaid).

```mermaid
erDiagram
  User {
    String id PK
    String phone
    String email
    String passwordHash
    String name
    AccountType accountType
    UserRole role
    VerificationStatus verificationStatus
    DateTime verifiedAt
    Boolean isActive
    DateTime createdAt
    DateTime updatedAt
  }
  BusinessProfile {
    String userId PK FK
    String displayName
    String logoUrl
    String bio
    String licenseNumber
    DateTime createdAt
    DateTime updatedAt
  }
  District {
    Int id PK
    String name
    Int sortOrder
    Boolean isActive
  }
  Project {
    String id PK
    String ownerId FK
    Int districtId FK
    String name
    String description
    String coverUrl
    Int unitsCount
    Int deliveryYear
    Boolean isReadyNow
    Boolean isActive
    DateTime createdAt
    DateTime updatedAt
  }
  Property {
    String id PK
    String ownerId FK
    String projectId FK
    Int districtId FK
    String title
    String description
    PropertyType type
    ListingType listingType
    Decimal price
    Int area
    Int beds
    Int baths
    FinishingLevel finishing
    PaymentMethod[] paymentMethods
    String[] features
    PropertyStatus status
    Boolean isFeatured
    Boolean isVerified
    Int viewsCount
    DateTime publishedAt
    DateTime createdAt
    DateTime updatedAt
  }
  PropertyImage {
    String id PK
    String propertyId FK
    String url
    Int position
    DateTime createdAt
  }
  Favorite {
    String userId PK FK
    String propertyId PK FK
    DateTime createdAt
  }
  InspectionRequest {
    String id PK
    Int number
    String propertyId FK
    String buyerId FK
    String ownerId FK
    InspectionStatus status
    DateTime visitDate
    InspectionSlot slot
    DateTime requestedVisitDate
    InspectionSlot requestedSlot
    Decimal feeAmount
    DateTime responseDeadline
    DateTime respondedAt
    DateTime confirmedAt
    DateTime closedAt
    DateTime createdAt
    DateTime updatedAt
  }
  InspectionEvent {
    String id PK
    String inspectionRequestId FK
    String actorId FK
    InspectionStatus fromStatus
    InspectionStatus toStatus
    String note
    DateTime createdAt
  }
  Payment {
    String id PK
    String userId FK
    String inspectionRequestId FK
    PaymentType type
    Decimal amount
    String currency
    PaymentStatus status
    String provider
    String providerRef
    String idempotencyKey
    String refundOfId FK
    RefundReason refundReason
    RefundDestination refundDestination
    DateTime createdAt
    DateTime completedAt
  }
  Deal {
    String id PK
    String propertyId FK
    String buyerId FK
    String sellerId FK
    String inspectionRequestId FK
    Decimal agreedPrice
    Decimal inspectionCredit
    Decimal commissionAmount
    DealStatus status
    DateTime closedAt
    DateTime createdAt
    DateTime updatedAt
  }
  Notification {
    String id PK
    String userId FK
    NotificationType type
    String title
    String body
    Json data
    DateTime readAt
    DateTime createdAt
  }
  Setting {
    String key PK
    Json value
    DateTime updatedAt
  }
  User ||--o| BusinessProfile : "userId"
  User ||--o{ Project : "ownerId"
  District |o--o{ Project : "districtId"
  User ||--o{ Property : "ownerId"
  Project |o--o{ Property : "projectId"
  District ||--o{ Property : "districtId"
  Property ||--o{ PropertyImage : "propertyId"
  User ||--o{ Favorite : "userId"
  Property ||--o{ Favorite : "propertyId"
  Property ||--o{ InspectionRequest : "propertyId"
  User ||--o{ InspectionRequest : "buyerId"
  User ||--o{ InspectionRequest : "ownerId"
  InspectionRequest ||--o{ InspectionEvent : "inspectionRequestId"
  User |o--o{ InspectionEvent : "actorId"
  User ||--o{ Payment : "userId"
  InspectionRequest |o--o{ Payment : "inspectionRequestId"
  Payment |o--o{ Payment : "refundOfId"
  Property ||--o{ Deal : "propertyId"
  User ||--o{ Deal : "buyerId"
  User ||--o{ Deal : "sellerId"
  InspectionRequest |o--o| Deal : "inspectionRequestId"
  User ||--o{ Notification : "userId"
```
