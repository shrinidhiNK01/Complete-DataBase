# MongoDB Complete Notes: Beginner to Advanced

Updated: 2026-06-11  
Focus: MongoDB Shell (`mongosh`), MongoDB Atlas, CRUD, aggregation, data modeling, indexes, transactions, replication, sharding, Python, and interview prep.

Official references used:
- MongoDB Manual: https://www.mongodb.com/docs/manual/
- MongoDB Release Notes: https://www.mongodb.com/docs/manual/release-notes/
- CRUD docs: https://www.mongodb.com/docs/manual/crud/
- Aggregation docs: https://www.mongodb.com/docs/manual/aggregation/
- Index docs: https://www.mongodb.com/docs/manual/indexes/
- Transactions docs: https://www.mongodb.com/docs/manual/core/transactions/
- Atlas docs: https://www.mongodb.com/docs/atlas/

As of this guide, MongoDB docs list MongoDB 8.3-series as the current stable release. Most commands below work across modern MongoDB versions.

---

## Course Contents

1. Intro
2. What is MongoDB?
3. Installation on Windows
4. Installation on macOS
5. MongoDB basic queries
6. MongoDB Atlas
7. Create and drop databases and collections
8. CRUD operations
9. MongoDB data types
10. Query operators
11. Cursor methods
12. Aggregation framework
13. String, arithmetic, condition, and variable operators
14. Data modeling
15. Schema validation
16. Indexes
17. Transactions
18. Sharding
19. Replica sets
20. Python with MongoDB project
21. Security, backup, performance, and production checklist
22. Interview questions

---

## 1. Intro

MongoDB is a NoSQL document database.

SQL databases usually store data in tables, rows, and columns.

MongoDB stores data in collections and documents.

Simple comparison:

| SQL | MongoDB |
|---|---|
| Database | Database |
| Table | Collection |
| Row | Document |
| Column | Field |
| Primary key | `_id` |
| Join | `$lookup` or embedded documents |

Example SQL-style data:

```text
users table
id | name | age
1  | Ravi | 22
```

MongoDB-style document:

```javascript
{
  _id: ObjectId("..."),
  name: "Ravi",
  age: 22
}
```

MongoDB is useful when:

- Your data looks like objects or JSON.
- Your schema changes often.
- You need fast development.
- You need horizontal scaling.
- You need nested data like user profile, cart items, addresses, comments, etc.

---

## 2. What is MongoDB?

MongoDB is a document database. It stores data in BSON, which is a binary form of JSON.

JSON-like document:

```javascript
{
  name: "Asha",
  email: "asha@example.com",
  skills: ["Python", "MongoDB"],
  address: {
    city: "Bengaluru",
    country: "India"
  }
}
```

Important MongoDB ideas:

- Document: one record.
- Collection: group of documents.
- Database: group of collections.
- Field: key inside a document.
- Value: data stored in a field.
- `_id`: unique identifier automatically created by MongoDB.
- BSON: storage format used internally by MongoDB.

Why MongoDB is called schema-flexible:

In one collection, documents can have different fields.

```javascript
{ name: "Ravi", age: 22 }
{ name: "Meera", email: "meera@example.com", premium: true }
```

This is flexible, but you should still design a clean schema in real projects.

---

## 3. Installation on Windows

### Option A: Install MongoDB Community Server

1. Go to https://www.mongodb.com/try/download/community
2. Select Windows.
3. Download MSI installer.
4. During setup, choose "Complete".
5. Install MongoDB as a Windows service.
6. Install MongoDB Compass if offered.

Check service:

```powershell
Get-Service MongoDB
```

Start service:

```powershell
Start-Service MongoDB
```

Open shell:

```powershell
mongosh
```

If `mongosh` is not recognized, install MongoDB Shell from:

https://www.mongodb.com/try/download/shell

### Option B: Use Atlas instead of local install

Atlas is easier for beginners because MongoDB runs in the cloud.

Use Atlas if:

- You do not want to manage local server setup.
- You want a free cluster for practice.
- You want to connect from Node.js, Python, Java, etc.

---

## 4. Installation on macOS

Using Homebrew:

```bash
brew tap mongodb/brew
brew install mongodb-community
brew services start mongodb-community
mongosh
```

Stop service:

```bash
brew services stop mongodb-community
```

Check version:

```bash
mongod --version
mongosh --version
```

---

## 5. MongoDB Shell Basics

Open MongoDB Shell:

```bash
mongosh
```

Show databases:

```javascript
show dbs
```

Use or create database:

```javascript
use school
```

Show current database:

```javascript
db
```

Show collections:

```javascript
show collections
```

Clear screen:

```javascript
cls
```

Help:

```javascript
help
db.help()
db.students.help()
```

---

## 6. MongoDB Atlas

MongoDB Atlas is MongoDB's managed cloud database service.

Atlas handles:

- Cluster creation
- Backups
- Monitoring
- Security settings
- Scaling
- Cloud deployment on AWS, Azure, or Google Cloud

Basic Atlas steps:

1. Create account at https://www.mongodb.com/cloud/atlas
2. Create a project.
3. Create a free or paid cluster.
4. Create database user.
5. Add your IP address to the access list.
6. Click Connect.
7. Choose Compass, Shell, or Driver.
8. Copy connection string.

Example connection string:

```text
mongodb+srv://username:password@cluster0.xxxxx.mongodb.net/school
```

Never hardcode real passwords in production code. Use environment variables.

---

## 7. Create and Drop Database and Collection

MongoDB creates a database only after you insert data.

```javascript
use college
db.students.insertOne({ name: "Ravi", age: 21 })
show dbs
```

Create collection manually:

```javascript
db.createCollection("teachers")
```

Drop collection:

```javascript
db.teachers.drop()
```

Drop database:

```javascript
use college
db.dropDatabase()
```

Rename collection:

```javascript
db.students.renameCollection("learners")
```

---

## 8. CRUD Operations

CRUD means:

- Create
- Read
- Update
- Delete

Sample collection:

```javascript
use shop

db.products.insertMany([
  { name: "Laptop", price: 60000, category: "electronics", stock: 10, tags: ["computer", "work"] },
  { name: "Mouse", price: 700, category: "electronics", stock: 50, tags: ["computer", "accessory"] },
  { name: "Notebook", price: 80, category: "stationery", stock: 100, tags: ["paper", "study"] },
  { name: "Pen", price: 20, category: "stationery", stock: 200, tags: ["writing"] }
])
```

### Create

Insert one document:

```javascript
db.products.insertOne({
  name: "Keyboard",
  price: 1500,
  category: "electronics",
  stock: 25
})
```

Insert many:

```javascript
db.products.insertMany([
  { name: "Bag", price: 1200, category: "fashion", stock: 15 },
  { name: "Bottle", price: 300, category: "home", stock: 40 }
])
```

### Read

Find all:

```javascript
db.products.find()
```

Pretty output:

```javascript
db.products.find().pretty()
```

Find one:

```javascript
db.products.findOne({ name: "Laptop" })
```

Filter:

```javascript
db.products.find({ category: "electronics" })
```

Projection means choosing fields:

```javascript
db.products.find(
  { category: "electronics" },
  { name: 1, price: 1, _id: 0 }
)
```

### Update

Update one:

```javascript
db.products.updateOne(
  { name: "Mouse" },
  { $set: { price: 800 } }
)
```

Update many:

```javascript
db.products.updateMany(
  { category: "stationery" },
  { $set: { discount: 10 } }
)
```

Increase value:

```javascript
db.products.updateOne(
  { name: "Laptop" },
  { $inc: { stock: -1 } }
)
```

Add field only if document is inserted:

```javascript
db.products.updateOne(
  { name: "Monitor" },
  { $set: { price: 12000, category: "electronics", stock: 5 } },
  { upsert: true }
)
```

### Delete

Delete one:

```javascript
db.products.deleteOne({ name: "Pen" })
```

Delete many:

```javascript
db.products.deleteMany({ stock: 0 })
```

Delete all documents but keep collection:

```javascript
db.products.deleteMany({})
```

---

## 9. MongoDB Data Types

Common data types:

| Type | Example |
|---|---|
| String | `"Ravi"` |
| Number | `25`, `99.5` |
| Boolean | `true`, `false` |
| Date | `new Date()` |
| Array | `["red", "blue"]` |
| Object | `{ city: "Delhi" }` |
| ObjectId | `ObjectId("...")` |
| Null | `null` |
| Decimal128 | `NumberDecimal("99.99")` |

Example:

```javascript
db.users.insertOne({
  name: "Nisha",
  age: 24,
  isActive: true,
  joinedAt: new Date(),
  hobbies: ["reading", "coding"],
  address: {
    city: "Mumbai",
    pin: 400001
  },
  wallet: NumberDecimal("1500.75"),
  middleName: null
})
```

Find by ObjectId:

```javascript
db.users.findOne({ _id: ObjectId("PUT_ID_HERE") })
```

---

## 10. Query Operators

Comparison operators:

```javascript
db.products.find({ price: { $gt: 1000 } })   // greater than
db.products.find({ price: { $gte: 1000 } })  // greater than or equal
db.products.find({ price: { $lt: 1000 } })   // less than
db.products.find({ price: { $lte: 1000 } })  // less than or equal
db.products.find({ price: { $eq: 700 } })    // equal
db.products.find({ price: { $ne: 700 } })    // not equal
```

Match multiple possible values:

```javascript
db.products.find({ category: { $in: ["electronics", "fashion"] } })
db.products.find({ category: { $nin: ["electronics"] } })
```

Logical operators:

```javascript
db.products.find({
  $and: [
    { category: "electronics" },
    { price: { $gt: 1000 } }
  ]
})

db.products.find({
  $or: [
    { category: "electronics" },
    { price: { $lt: 100 } }
  ]
})

db.products.find({
  price: { $not: { $gt: 1000 } }
})

db.products.find({
  $nor: [
    { category: "electronics" },
    { category: "fashion" }
  ]
})
```

Element operators:

```javascript
db.products.find({ discount: { $exists: true } })
db.products.find({ price: { $type: "number" } })
```

Array operators:

```javascript
db.products.find({ tags: "computer" })
db.products.find({ tags: { $all: ["computer", "work"] } })
db.products.find({ tags: { $size: 2 } })
```

Nested object query:

```javascript
db.users.find({ "address.city": "Mumbai" })
```

Regular expression:

```javascript
db.products.find({ name: /^Lap/ })
db.products.find({ name: { $regex: "top", $options: "i" } })
```

---

## 11. Update Operators

Set field:

```javascript
db.users.updateOne({ name: "Nisha" }, { $set: { age: 25 } })
```

Remove field:

```javascript
db.users.updateOne({ name: "Nisha" }, { $unset: { middleName: "" } })
```

Increment:

```javascript
db.users.updateOne({ name: "Nisha" }, { $inc: { age: 1 } })
```

Rename field:

```javascript
db.users.updateMany({}, { $rename: { joinedAt: "createdAt" } })
```

Array push:

```javascript
db.users.updateOne({ name: "Nisha" }, { $push: { hobbies: "music" } })
```

Array add without duplicate:

```javascript
db.users.updateOne({ name: "Nisha" }, { $addToSet: { hobbies: "coding" } })
```

Remove array value:

```javascript
db.users.updateOne({ name: "Nisha" }, { $pull: { hobbies: "music" } })
```

Remove first or last array item:

```javascript
db.users.updateOne({ name: "Nisha" }, { $pop: { hobbies: 1 } })  // last
db.users.updateOne({ name: "Nisha" }, { $pop: { hobbies: -1 } }) // first
```

Update array element:

```javascript
db.orders.updateOne(
  { _id: 1, "items.name": "Pen" },
  { $set: { "items.$.qty": 5 } }
)
```

---

## 12. Cursor Methods

`find()` returns a cursor. A cursor is like a pointer to query results.

Limit:

```javascript
db.products.find().limit(2)
```

Skip:

```javascript
db.products.find().skip(2)
```

Sort ascending:

```javascript
db.products.find().sort({ price: 1 })
```

Sort descending:

```javascript
db.products.find().sort({ price: -1 })
```

Pagination:

```javascript
db.products.find()
  .sort({ _id: 1 })
  .skip(20)
  .limit(10)
```

Count:

```javascript
db.products.countDocuments({ category: "electronics" })
db.products.estimatedDocumentCount()
```

Distinct:

```javascript
db.products.distinct("category")
```

Explain query:

```javascript
db.products.find({ price: { $gt: 1000 } }).explain("executionStats")
```

---

## 13. Aggregation Framework

Aggregation is used to process data and produce calculated results.

Think of aggregation like a pipeline:

```text
documents -> stage 1 -> stage 2 -> stage 3 -> result
```

Basic syntax:

```javascript
db.collection.aggregate([
  { stage1 },
  { stage2 }
])
```

Sample data:

```javascript
db.orders.insertMany([
  { customer: "Ravi", item: "Laptop", category: "electronics", price: 60000, qty: 1, status: "paid" },
  { customer: "Ravi", item: "Mouse", category: "electronics", price: 700, qty: 2, status: "paid" },
  { customer: "Asha", item: "Notebook", category: "stationery", price: 80, qty: 5, status: "pending" },
  { customer: "Meera", item: "Pen", category: "stationery", price: 20, qty: 10, status: "paid" }
])
```

### `$match`

Filters documents.

```javascript
db.orders.aggregate([
  { $match: { status: "paid" } }
])
```

### `$project`

Selects or creates fields.

```javascript
db.orders.aggregate([
  {
    $project: {
      _id: 0,
      customer: 1,
      item: 1,
      total: { $multiply: ["$price", "$qty"] }
    }
  }
])
```

### `$group`

Groups data.

```javascript
db.orders.aggregate([
  {
    $group: {
      _id: "$customer",
      totalSpent: { $sum: { $multiply: ["$price", "$qty"] } },
      orderCount: { $sum: 1 }
    }
  }
])
```

### `$sort`

```javascript
db.orders.aggregate([
  {
    $group: {
      _id: "$category",
      revenue: { $sum: { $multiply: ["$price", "$qty"] } }
    }
  },
  { $sort: { revenue: -1 } }
])
```

### `$limit` and `$skip`

```javascript
db.orders.aggregate([
  { $sort: { price: -1 } },
  { $skip: 0 },
  { $limit: 3 }
])
```

### `$unwind`

Breaks array values into separate documents.

```javascript
db.blogs.insertOne({
  title: "MongoDB Guide",
  tags: ["database", "nosql", "backend"]
})

db.blogs.aggregate([
  { $unwind: "$tags" }
])
```

### `$lookup`

Performs a left outer join.

```javascript
db.customers.insertMany([
  { _id: 1, name: "Ravi" },
  { _id: 2, name: "Asha" }
])

db.invoices.insertMany([
  { invoiceNo: "I1", customerId: 1, amount: 5000 },
  { invoiceNo: "I2", customerId: 1, amount: 2000 }
])

db.customers.aggregate([
  {
    $lookup: {
      from: "invoices",
      localField: "_id",
      foreignField: "customerId",
      as: "invoices"
    }
  }
])
```

### `$facet`

Runs multiple pipelines at the same time.

```javascript
db.products.aggregate([
  {
    $facet: {
      byCategory: [
        { $group: { _id: "$category", count: { $sum: 1 } } }
      ],
      expensive: [
        { $match: { price: { $gt: 1000 } } },
        { $project: { name: 1, price: 1, _id: 0 } }
      ]
    }
  }
])
```

### `$out` and `$merge`

`$out` writes result to a collection.

```javascript
db.orders.aggregate([
  { $match: { status: "paid" } },
  { $out: "paid_orders" }
])
```

`$merge` merges result into a collection.

```javascript
db.orders.aggregate([
  {
    $group: {
      _id: "$customer",
      totalSpent: { $sum: { $multiply: ["$price", "$qty"] } }
    }
  },
  {
    $merge: {
      into: "customer_totals",
      on: "_id",
      whenMatched: "replace",
      whenNotMatched: "insert"
    }
  }
])
```

---

## 14. Aggregation String Operators

Convert to uppercase:

```javascript
db.users.aggregate([
  { $project: { nameUpper: { $toUpper: "$name" } } }
])
```

Convert to lowercase:

```javascript
db.users.aggregate([
  { $project: { nameLower: { $toLower: "$name" } } }
])
```

Concatenate:

```javascript
db.users.aggregate([
  {
    $project: {
      fullName: { $concat: ["$firstName", " ", "$lastName"] }
    }
  }
])
```

Substring:

```javascript
db.users.aggregate([
  { $project: { shortName: { $substrCP: ["$name", 0, 3] } } }
])
```

String length:

```javascript
db.users.aggregate([
  { $project: { nameLength: { $strLenCP: "$name" } } }
])
```

Trim:

```javascript
db.users.aggregate([
  { $project: { cleanName: { $trim: { input: "$name" } } } }
])
```

---

## 15. Aggregation Arithmetic Operators

Add:

```javascript
{ $add: ["$price", "$tax"] }
```

Subtract:

```javascript
{ $subtract: ["$mrp", "$discount"] }
```

Multiply:

```javascript
{ $multiply: ["$price", "$qty"] }
```

Divide:

```javascript
{ $divide: ["$total", "$qty"] }
```

Modulo:

```javascript
{ $mod: ["$number", 2] }
```

Example:

```javascript
db.orders.aggregate([
  {
    $project: {
      item: 1,
      subtotal: { $multiply: ["$price", "$qty"] },
      tax: { $multiply: [{ $multiply: ["$price", "$qty"] }, 0.18] },
      _id: 0
    }
  }
])
```

---

## 16. Conditions: IF-ELSE in MongoDB

Use `$cond` for if-else.

```javascript
db.products.aggregate([
  {
    $project: {
      name: 1,
      price: 1,
      priceType: {
        $cond: {
          if: { $gt: ["$price", 1000] },
          then: "expensive",
          else: "cheap"
        }
      }
    }
  }
])
```

Use `$switch` for multiple conditions.

```javascript
db.students.aggregate([
  {
    $project: {
      name: 1,
      marks: 1,
      grade: {
        $switch: {
          branches: [
            { case: { $gte: ["$marks", 90] }, then: "A" },
            { case: { $gte: ["$marks", 75] }, then: "B" },
            { case: { $gte: ["$marks", 60] }, then: "C" }
          ],
          default: "D"
        }
      }
    }
  }
])
```

Handle null:

```javascript
db.users.aggregate([
  {
    $project: {
      name: { $ifNull: ["$name", "Unknown"] }
    }
  }
])
```

---

## 17. Variables in MongoDB Aggregation

`$` refers to a field.

```javascript
"$price"
```

`$$` refers to a variable.

Common system variables:

| Variable | Meaning |
|---|---|
| `$$ROOT` | Full current document |
| `$$CURRENT` | Current processing document |
| `$$NOW` | Current datetime |
| `$$REMOVE` | Exclude a field conditionally |

Example using `$let`:

```javascript
db.orders.aggregate([
  {
    $project: {
      item: 1,
      finalAmount: {
        $let: {
          vars: {
            subtotal: { $multiply: ["$price", "$qty"] }
          },
          in: { $add: ["$$subtotal", { $multiply: ["$$subtotal", 0.18] }] }
        }
      }
    }
  }
])
```

Example using `$map`:

```javascript
db.carts.aggregate([
  {
    $project: {
      updatedItems: {
        $map: {
          input: "$items",
          as: "item",
          in: {
            name: "$$item.name",
            total: { $multiply: ["$$item.price", "$$item.qty"] }
          }
        }
      }
    }
  }
])
```

---

## 18. Data Modeling in MongoDB

Data modeling means deciding how to structure documents.

Main choices:

1. Embed data inside one document.
2. Reference data using IDs.

### Embedding

Good when related data is usually read together.

```javascript
{
  _id: 1,
  name: "Ravi",
  addresses: [
    { type: "home", city: "Delhi" },
    { type: "office", city: "Gurugram" }
  ]
}
```

Use embedding for:

- One-to-one relationships
- One-to-few relationships
- Data that belongs strongly to parent
- Fast reads

Avoid embedding when:

- Array can grow without limit.
- Child data is updated independently often.
- Same child data is shared by many parents.

### Referencing

Good when data is large or shared.

```javascript
// users
{ _id: 1, name: "Ravi" }

// orders
{ _id: 101, userId: 1, total: 5000 }
```

Use references for:

- One-to-many with many children
- Many-to-many relationships
- Large subdocuments
- Data that changes independently

### One-to-one

Embed:

```javascript
{
  name: "Ravi",
  profile: {
    bio: "Backend developer",
    website: "https://example.com"
  }
}
```

### One-to-many

Embed if small:

```javascript
{
  title: "MongoDB Notes",
  comments: [
    { user: "Asha", text: "Helpful" },
    { user: "Ravi", text: "Nice" }
  ]
}
```

Reference if large:

```javascript
// posts
{ _id: 1, title: "MongoDB Notes" }

// comments
{ postId: 1, user: "Asha", text: "Helpful" }
```

### Many-to-many

```javascript
// students
{ _id: 1, name: "Ravi", courseIds: [101, 102] }

// courses
{ _id: 101, title: "MongoDB" }
```

### Rule of thumb

Model data based on your most common queries.

Ask:

- What will the app read most often?
- What will the app update most often?
- Can this array grow forever?
- Does this data need to be reused elsewhere?
- Do I need strong consistency across multiple documents?

---

## 19. Schema Validation

MongoDB is flexible, but you can enforce rules.

Create collection with validation:

```javascript
db.createCollection("students", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["name", "age", "email"],
      properties: {
        name: {
          bsonType: "string",
          description: "name must be a string"
        },
        age: {
          bsonType: "int",
          minimum: 18,
          description: "age must be an integer and at least 18"
        },
        email: {
          bsonType: "string",
          pattern: "^.+@.+\\..+$",
          description: "email must be valid"
        }
      }
    }
  }
})
```

Valid insert:

```javascript
db.students.insertOne({
  name: "Ravi",
  age: 21,
  email: "ravi@example.com"
})
```

Invalid insert:

```javascript
db.students.insertOne({
  name: "Ravi",
  age: 15,
  email: "wrong"
})
```

Modify validation:

```javascript
db.runCommand({
  collMod: "students",
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["name"],
      properties: {
        name: { bsonType: "string" }
      }
    }
  },
  validationLevel: "moderate",
  validationAction: "error"
})
```

Validation levels:

- `strict`: apply rules to all inserts and updates.
- `moderate`: apply rules to inserts and to updates of valid existing documents.

Validation actions:

- `error`: reject invalid writes.
- `warn`: allow write but log warning.

---

## 20. Indexes

Indexes make reads faster, but writes slower because indexes must also be updated.

Without index:

```text
MongoDB scans many documents.
```

With index:

```text
MongoDB jumps quickly to matching documents.
```

Create single-field index:

```javascript
db.products.createIndex({ name: 1 })
```

Create descending index:

```javascript
db.products.createIndex({ price: -1 })
```

Create compound index:

```javascript
db.products.createIndex({ category: 1, price: -1 })
```

Use this for queries like:

```javascript
db.products.find({ category: "electronics" }).sort({ price: -1 })
```

Unique index:

```javascript
db.users.createIndex({ email: 1 }, { unique: true })
```

Sparse index:

```javascript
db.users.createIndex({ phone: 1 }, { sparse: true })
```

Partial index:

```javascript
db.orders.createIndex(
  { customerId: 1 },
  { partialFilterExpression: { status: "active" } }
)
```

TTL index automatically deletes old documents:

```javascript
db.sessions.createIndex(
  { createdAt: 1 },
  { expireAfterSeconds: 3600 }
)
```

Text index:

```javascript
db.articles.createIndex({ title: "text", body: "text" })
db.articles.find({ $text: { $search: "mongodb database" } })
```

Geospatial index:

```javascript
db.places.createIndex({ location: "2dsphere" })

db.places.find({
  location: {
    $near: {
      $geometry: { type: "Point", coordinates: [77.5946, 12.9716] },
      $maxDistance: 5000
    }
  }
})
```

List indexes:

```javascript
db.products.getIndexes()
```

Drop index:

```javascript
db.products.dropIndex({ name: 1 })
```

Check query plan:

```javascript
db.products.find({ name: "Laptop" }).explain("executionStats")
```

Important index rules:

- Create indexes for frequent queries.
- Do not index every field.
- Compound index field order matters.
- Indexes use disk and memory.
- Use `explain()` to confirm the index is used.

---

## 21. Transactions

A transaction groups multiple operations into one all-or-nothing unit.

Use transactions when:

- Money transfer must update two accounts together.
- Order creation must update order, payment, and inventory together.
- Multiple documents must stay consistent.

MongoDB single-document writes are already atomic. Many MongoDB designs avoid transactions by embedding related data inside one document.

Example transaction in `mongosh`:

```javascript
const session = db.getMongo().startSession()
session.startTransaction()

try {
  const accounts = session.getDatabase("bank").accounts

  accounts.updateOne(
    { _id: "A" },
    { $inc: { balance: -500 } }
  )

  accounts.updateOne(
    { _id: "B" },
    { $inc: { balance: 500 } }
  )

  session.commitTransaction()
} catch (error) {
  session.abortTransaction()
  throw error
} finally {
  session.endSession()
}
```

Important:

- Transactions need replica set or sharded cluster deployment.
- Keep transactions short.
- Avoid long-running user interactions inside transactions.
- Use transactions only when needed.

---

## 22. Replication

Replication means keeping copies of data on multiple servers.

MongoDB replication uses replica sets.

Replica set members:

- Primary: accepts writes.
- Secondary: copies data from primary.
- Arbiter: votes in election but does not store data.

Why replication is useful:

- High availability
- Automatic failover
- Data redundancy
- Read scaling in some cases

Basic local replica set idea:

```bash
mongod --replSet rs0 --dbpath /data/db --port 27017
```

Initiate replica set:

```javascript
rs.initiate()
rs.status()
```

Add member:

```javascript
rs.add("host2:27017")
```

Check primary:

```javascript
rs.isMaster()
```

In modern scripts, use:

```javascript
db.hello()
```

Read preference examples:

```javascript
db.getMongo().setReadPref("primary")
db.getMongo().setReadPref("secondary")
```

Replication concepts:

- Oplog: operation log used by secondaries to copy changes.
- Election: process of choosing a new primary.
- Write concern: controls write acknowledgement.
- Read concern: controls read isolation/consistency.

Write concern example:

```javascript
db.orders.insertOne(
  { item: "Laptop" },
  { writeConcern: { w: "majority", j: true } }
)
```

---

## 23. Sharding

Sharding means splitting data across multiple servers.

Use sharding when:

- Data is too large for one server.
- Write/read load is too high for one server.
- You need horizontal scaling.

Main parts:

- Shard: stores a subset of data.
- `mongos`: query router.
- Config servers: store cluster metadata.
- Shard key: field used to distribute data.

Example:

```javascript
sh.enableSharding("shop")
sh.shardCollection("shop.orders", { customerId: 1 })
```

Hashed shard key:

```javascript
sh.shardCollection("shop.orders", { customerId: "hashed" })
```

Good shard key should:

- Have high cardinality.
- Distribute writes evenly.
- Match common query patterns.
- Avoid creating one hot shard.

Bad shard key examples:

- Boolean field like `isActive`
- Low-cardinality field like `status`
- Always-increasing field like timestamp if not planned carefully

Sharding is powerful, but wrong shard keys are painful to fix. Design carefully.

---

## 24. Security Basics

Create admin user:

```javascript
use admin
db.createUser({
  user: "admin",
  pwd: passwordPrompt(),
  roles: [ { role: "userAdminAnyDatabase", db: "admin" } ]
})
```

Create app user:

```javascript
use shop
db.createUser({
  user: "shop_app",
  pwd: passwordPrompt(),
  roles: [ { role: "readWrite", db: "shop" } ]
})
```

Connection with auth:

```bash
mongosh "mongodb://localhost:27017/shop" -u shop_app -p
```

Security checklist:

- Enable authentication.
- Use strong passwords.
- Use least privilege roles.
- Restrict network access.
- Use TLS in production.
- Do not expose MongoDB directly to the public internet.
- Store secrets in environment variables.
- Keep MongoDB patched.
- Enable backups.

---

## 25. Backup and Restore

Export JSON:

```bash
mongoexport --db shop --collection products --out products.json
```

Import JSON:

```bash
mongoimport --db shop --collection products --file products.json
```

Binary backup:

```bash
mongodump --db shop --out backup
```

Restore:

```bash
mongorestore backup
```

For Atlas, prefer Atlas backups for production.

---

## 26. Performance Checklist

To make MongoDB fast:

- Design documents based on query patterns.
- Use indexes for frequent filters and sorts.
- Use projection to return only needed fields.
- Avoid unbounded arrays.
- Avoid very large documents.
- Use `explain("executionStats")`.
- Keep working set in memory when possible.
- Avoid unnecessary `$lookup` in hot paths.
- Put `$match` early in aggregation pipelines.
- Use pagination carefully.
- Avoid huge skips for deep pages.

Better pagination:

```javascript
db.products.find({ _id: { $gt: lastSeenId } })
  .sort({ _id: 1 })
  .limit(20)
```

---

## 27. Python with MongoDB: Simple Project

Install package:

```bash
pip install pymongo
```

Project: Student Management CRUD

File: `app.py`

```python
from pymongo import MongoClient
from bson.objectid import ObjectId

client = MongoClient("mongodb://localhost:27017")
db = client["college"]
students = db["students"]


def create_student(name, age, course):
    result = students.insert_one({
        "name": name,
        "age": age,
        "course": course
    })
    print("Inserted ID:", result.inserted_id)


def list_students():
    for student in students.find():
        print(student)


def find_student(student_id):
    student = students.find_one({"_id": ObjectId(student_id)})
    print(student)


def update_student(student_id, new_course):
    result = students.update_one(
        {"_id": ObjectId(student_id)},
        {"$set": {"course": new_course}}
    )
    print("Modified:", result.modified_count)


def delete_student(student_id):
    result = students.delete_one({"_id": ObjectId(student_id)})
    print("Deleted:", result.deleted_count)


if __name__ == "__main__":
    create_student("Ravi", 21, "MongoDB")
    create_student("Asha", 22, "Python")
    list_students()
```

Atlas connection in Python:

```python
from pymongo import MongoClient
import os

uri = os.environ["MONGODB_URI"]
client = MongoClient(uri)
db = client["college"]
```

Set environment variable:

```bash
set MONGODB_URI=mongodb+srv://username:password@cluster0.xxxxx.mongodb.net/
```

In PowerShell:

```powershell
$env:MONGODB_URI="mongodb+srv://username:password@cluster0.xxxxx.mongodb.net/"
```

---

## 28. Common Mistakes

Do not:

- Store passwords in plain text.
- Put every field into an index.
- Use MongoDB without authentication in production.
- Use one huge document for unlimited child data.
- Use `$where` for normal queries.
- Forget to handle duplicate key errors.
- Use `skip()` for very deep pagination.
- Assume flexible schema means no schema design.

Do:

- Create indexes based on real queries.
- Use schema validation for important collections.
- Use Atlas backups or tested backup scripts.
- Store secrets outside code.
- Test queries with realistic data size.
- Monitor slow queries.

---

## 29. Mini Practice Tasks

### Task 1: Create library database

```javascript
use library

db.books.insertMany([
  { title: "Clean Code", author: "Robert Martin", price: 500, genres: ["programming"], stock: 5 },
  { title: "Atomic Habits", author: "James Clear", price: 350, genres: ["self-help"], stock: 10 },
  { title: "MongoDB Guide", author: "Asha", price: 250, genres: ["database", "programming"], stock: 8 }
])
```

Questions:

```javascript
db.books.find()
db.books.find({ price: { $lt: 400 } })
db.books.find({ genres: "programming" })
db.books.updateOne({ title: "MongoDB Guide" }, { $inc: { stock: -1 } })
db.books.createIndex({ title: 1 })
```

### Task 2: Aggregate sales

```javascript
db.sales.insertMany([
  { product: "Pen", qty: 10, price: 20, date: new Date("2026-01-01") },
  { product: "Pen", qty: 5, price: 20, date: new Date("2026-01-02") },
  { product: "Book", qty: 2, price: 200, date: new Date("2026-01-02") }
])

db.sales.aggregate([
  {
    $group: {
      _id: "$product",
      totalQty: { $sum: "$qty" },
      revenue: { $sum: { $multiply: ["$qty", "$price"] } }
    }
  },
  { $sort: { revenue: -1 } }
])
```

---

## 30. Interview Questions and Answers

### 1. What is MongoDB?

MongoDB is a NoSQL document database that stores data in flexible BSON documents.

### 2. What is a document?

A document is one record in MongoDB. It contains field-value pairs.

### 3. What is a collection?

A collection is a group of documents. It is similar to a table in SQL.

### 4. What is `_id`?

`_id` is the unique primary key of a document. MongoDB creates it automatically if you do not provide one.

### 5. What is BSON?

BSON is Binary JSON. MongoDB uses BSON internally to store documents efficiently and support extra data types.

### 6. Difference between SQL and MongoDB?

SQL uses tables and fixed schemas. MongoDB uses collections and flexible documents.

### 7. What is CRUD?

CRUD means Create, Read, Update, Delete.

### 8. What is `insertOne()`?

It inserts one document into a collection.

### 9. What is `insertMany()`?

It inserts multiple documents.

### 10. What is projection?

Projection controls which fields are returned by a query.

### 11. What is an index?

An index is a data structure that helps MongoDB find documents faster.

### 12. Disadvantage of indexes?

Indexes slow down writes and use extra storage.

### 13. What is a compound index?

A compound index is an index on multiple fields.

### 14. What is aggregation?

Aggregation processes documents through stages to calculate results.

### 15. What is `$match`?

`$match` filters documents in an aggregation pipeline.

### 16. What is `$group`?

`$group` groups documents and calculates values like sum, average, min, and max.

### 17. What is `$lookup`?

`$lookup` joins documents from another collection.

### 18. What is schema validation?

Schema validation enforces rules for documents in a collection.

### 19. What is embedding?

Embedding stores related data inside the same document.

### 20. What is referencing?

Referencing stores related document IDs instead of embedding full data.

### 21. When should you embed?

Embed when related data is small, owned by the parent, and read together.

### 22. When should you reference?

Reference when related data is large, shared, or updated independently.

### 23. What is a replica set?

A replica set is a group of MongoDB servers that maintain the same data for high availability.

### 24. What is primary in replica set?

Primary is the member that accepts writes.

### 25. What is secondary?

Secondary copies data from primary.

### 26. What is sharding?

Sharding splits data across multiple servers for horizontal scaling.

### 27. What is shard key?

Shard key is the field used to distribute data across shards.

### 28. What is a transaction?

A transaction groups multiple operations into one all-or-nothing unit.

### 29. Are single document writes atomic?

Yes. A single-document write in MongoDB is atomic.

### 30. What is Atlas?

MongoDB Atlas is MongoDB's managed cloud database service.

### 31. What is TTL index?

A TTL index automatically removes documents after a specific time.

### 32. What is `upsert`?

Upsert means update if found; insert if not found.

### 33. What is `explain()`?

`explain()` shows how MongoDB executes a query and whether indexes are used.

### 34. What is write concern?

Write concern controls how many acknowledgements MongoDB needs before considering a write successful.

### 35. What is read concern?

Read concern controls the consistency level of data returned by reads.

### 36. What is `ObjectId`?

`ObjectId` is a 12-byte unique identifier commonly used as `_id`.

### 37. Can MongoDB do joins?

Yes, using `$lookup`, but MongoDB data modeling often prefers embedding or references based on query patterns.

### 38. What is capped collection?

A capped collection is a fixed-size collection that preserves insertion order and removes oldest documents when full.

### 39. What is GridFS?

GridFS is a MongoDB specification for storing large files by splitting them into chunks.

### 40. How do you improve MongoDB performance?

Use good schema design, proper indexes, projections, aggregation optimization, monitoring, and avoid unbounded arrays.

---

## 31. Final Learning Path

Follow this order:

1. Learn documents, collections, and databases.
2. Practice `insertOne`, `find`, `updateOne`, and `deleteOne`.
3. Learn operators like `$gt`, `$in`, `$and`, `$or`, `$exists`.
4. Learn array and nested object queries.
5. Learn indexes and `explain()`.
6. Learn aggregation stages.
7. Learn data modeling.
8. Learn schema validation.
9. Learn transactions.
10. Learn Atlas.
11. Learn replication and sharding.
12. Build a project with Python, Node.js, Java, or your preferred language.

Best beginner project ideas:

- Student management system
- Expense tracker
- Blog API
- E-commerce product catalog
- Library management
- Chat app
- Task manager

---

## 32. Quick Command Cheat Sheet

```javascript
show dbs
use mydb
show collections
db.createCollection("users")
db.users.insertOne({ name: "Ravi" })
db.users.insertMany([{ name: "A" }, { name: "B" }])
db.users.find()
db.users.findOne({ name: "Ravi" })
db.users.updateOne({ name: "Ravi" }, { $set: { age: 22 } })
db.users.updateMany({}, { $set: { active: true } })
db.users.deleteOne({ name: "Ravi" })
db.users.deleteMany({ active: false })
db.users.createIndex({ email: 1 }, { unique: true })
db.users.getIndexes()
db.users.dropIndex({ email: 1 })
db.users.aggregate([{ $group: { _id: "$city", count: { $sum: 1 } } }])
db.users.countDocuments()
db.users.distinct("city")
db.users.find().sort({ name: 1 }).limit(10)
db.users.find().explain("executionStats")
db.users.drop()
db.dropDatabase()
```

---

## 33. Summary

MongoDB is simple at the start but very powerful at advanced levels.

The most important skills are:

- Writing correct CRUD queries
- Understanding operators
- Designing documents properly
- Creating useful indexes
- Using aggregation
- Knowing when to embed and when to reference
- Securing the database
- Monitoring and optimizing performance
- Understanding replica sets, sharding, and transactions

If you master these, you can confidently build real backend applications with MongoDB.
