# ASTERRA DevOps Assignment – Infrastructure
Diagram.png - ארכיטקטורה הבנה ראשונית .
## מה המטרה של הפרויקט
המטרה פה היא להרים תשתית ענן מלאה שמדגימה תרחיש אמיתי של קליטה, עיבוד והצגה של נתוני שטח.

בגדול המערכת עושה שלושה דברים:
1. שרת ציבורי באינטרנט שמריץ WordPress (ועוד קונטיינר GIS) כדי להציג תוצאות/מפות/"דשבורד" החוצה.
2. אזור פנימי וסגור לעיבוד נתונים וגישת מהנדס בלבד (Workstation פנימית + מסד נתונים RDS).
3. צינור אוטומטי לקליטת נתונים גולמיים מהשטח (S3 + Lambda) שמופעל אוטומטית על כל קובץ חדש.

הרעיון: מישהו "בשטח" מעלה קבצים (למשל צילומי לווין/דוחות/מדידות), אנחנו בולעים אותם אוטומטית, מעבדים פנימית, ומציגים תוצרים נקיים בצד הציבורי.

---

## ארכיטקטורה ברמה גבוהה
התשתית מחולקת לשני אזורים:

### אזור ציבורי (Public Zone)
- **Public EC2 Instance**  
  שרת EC2 עם Elastic IP, נגיש מהאינטרנט ב־HTTP (פורטים 80/443).  
  על השרת הזה רץ `docker-compose` שמרים שני קונטיינרים:
  - WordPress
  - MapServer (שרת מפות / GIS)
  
  השרת הזה הוא בעצם ה-"מסך" של המערכת: אפשר להיכנס עם דפדפן ולצרוך מידע.

### אזור פרטי (Private Zone)
- **Internal Workstation EC2**  
  מכונה פנימית בסאבנט פרטי (אין לה גישה מהאינטרנט).  
  אליה מתחברים ב־SSH (עם מפתח) כדי להריץ ניתוחים, כלים, סקריפטים.
  המכונה הזאת מדברת עם ה-RDS ויכולה למשוך קבצים גולמיים מה-S3.

- **RDS (PostgreSQL)**  
  מסד נתונים מנוהל של AWS.  
  מאוחסן ברשת פרטית בלבד (לא פתוח החוצה).  
  המטרה שלו היא לשמור נתונים מעובדים/מנוקים שאחרי זה אפשר להגיש ללקוחות/לממשק.

### Raw Data Landing Zone
- **S3 Bucket**  
  באקט ייעודי שקולט את כל הקבצים הגולמיים שמגיעים מהשטח. השם שלו נבנה אוטומטית לפי שם הפרויקט + סיומת רנדומלית, לדוגמה:
  `asterra-devops-raw-data-78515`

- מעלים לשם קבצים (תמונות, מפות, כל דבר).  
- כל העלאה של אובייקט חדש מפעילה פונקציית Lambda (ראה סעיף הבא).

### Event-driven Ingestion
- **AWS Lambda (`ingest-raw-object`)**  
  פונקציה שנקראת אוטומטית כל פעם שקובץ חדש עולה ל-S3.  
  כרגע היא לא עושה עיבוד כבד, אלא:
  - לוג של שם הקובץ והבאקט.
  - הוכחת חיים שה-Pipeline הזה עובד.
  
  הפונקציה רצה עם IAM Role משלה, ויש לה CloudWatch Logs.  
  כלומר: יש לנו תשתית ingest אוטומטית מבוססת אירוע (Event-driven).

---

## מה נבנה עם Terraform
את כל התשתית הרמתי באמצעות Terraform. המבנה של הקבצים מחולק ליחידות הגיוניות:

- `main.tf`  
  VPC, Subnets, Security Groups, Public EC2, Elastic IP וכו'.

- `db.tf`  
  RDS PostgreSQL (instance מנוהל של AWS).  
  נוצר עם גישה רק מהרשת הפנימית.

- `storage.tf`  
  S3 bucket ל-Raw Data (שם בסגנון `<project>-raw-data-<random>`).  
  כל הקבצים שמגיעים מהשטח נשמרים שם.

- `lambda.tf`  
  IAM Role ללמבדא  
  פונקציית Lambda (`ingest-raw-object`)  
  הרשאת invocation מ-S3 ללמבדא  
  חיבור ה-S3 bucket כטריגר ללמבדא (aws_s3_bucket_notification)

- `outputs.tf`  
  מדפיס ערכים חשובים אחרי `terraform apply`:
  - ה-IP הציבורי של השרת החיצוני (כדי שאפשר יהיה לפתוח דפדפן)
  - ה-endpoint של ה-RDS
  - שם הבאקט של ה-Raw Data
  - ה-IP של ה-Internal Workstation

- `env/dev.tfvars`  
  קובץ המשתנים (סיסמאות RDS, שם הפרויקט וכו') כדי לא לכתוב ערכים רגישים ישירות בתוך הקוד.

---

## איך מריצים את זה (שלב אחרי שלב)

### 1. הכנת ה-Backend של Terraform (נעשה פעם אחת)
יש לנו S3 ו-DynamoDB בשביל ה-Terraform state (ניהול State ונעילה).  
זה כבר הוגדר מראש עם:
- S3 ל-state
- טבלת DynamoDB ל-locks  
(הפרויקט הזה כבר רץ עם backend מרוחק, לא local state)

### 2. `terraform init`
בתיקייה של `infra/`:
```bash
terraform init
terraform plan -var-file="env/dev.tfvars"
terraform apply -var-file="env/dev.tfvars"
בסוף ה-apply Terraform מדפיס את ה-outputs. לדוגמה:

public_ec2_ip            = "3.120.217.172"
internal_workstation_ip  = "10.0.1.123"
raw_data_bucket          = "asterra-devops-raw-data-78515"d
db_endpoint              = "asterra-devops-db.XXXXX.eu-central-1.rds.amazonaws.com"

בדיקה : 
http://<public_ec2_ip>
 למשל ה ip : 3.120.217.172
מה אני אמור לראות?
ממשק WordPress (ולידו MapServer שרץ בתוך docker-compose).
זה מוכיח:

השרת הציבורי למעלה

ה-Security Group מאפשר HTTP מהאינטרנט

Docker רץ על ה-EC2.

בדיקה 2 :rds 
ה-DB (PostgreSQL RDS) לא פתוח לעולם.
הוא אמור להיות נגיש רק מתוך ה-Internal Workstation.

השלב:

תתחבר ב-SSH ל־Internal Workstation (הכתובת שקיבלת ב-output של internal_workstation_ip, או ה-public IP הזמני שלו אם הקצינו כזה לבדיקה).

תתקין psql (לקוח PostgreSQL).

תריץ פקודה כמו:

psql -h "<db_endpoint>" -U "<DB_USER>" -d "<DB_NAME>" -p 5432 -c "select version();"


אם אתה מקבל תשובה של גרסת PostgreSQL – החיבור הפנימי עובד וה-RDS חי.

בדיקה 3: ה-Pipeline של הקבצים (S3 → Lambda → CloudWatch)

זה החלק הקריטי שמראה שהמערכת מגיבה לאירועים.

קח קובץ כלשהו (למשל screenshot) ותעלה אותו ל-S3 bucket של ה-Raw Data.
אפשר דרך ה-AWS Console:
S3 → <raw_data_bucket> → Upload → בחר קובץ והעלה.

כנס ל-AWS Console → CloudWatch → Logs → Log groups.
תחפש לוג בשם:
/aws/lambda/ingest-raw-object

תיכנס ל-Log stream האחרון.
אתה אמור לראות לוג שנוצר "עכשיו", שמדווח משהו בסגנון:
New object uploaded: s3://asterra-devops-raw-data-78515/<filename>

מה זה מוכיח?

ה-S3 שלך מחובר כלוגיסטיקה של "Landing Zone".

כל קובץ חדש מפעיל Lambda אוטומטית.

הפונקציה רצה עם ה-IAM role שלה ושופכת מידע ל-CloudWatch.

זה נותן לנו אוטומציה של ingest (קליטה), בלי יד אדם.

זה הבסיס לעיבוד נתוני שטח אמיתי. בשלב הבא אפשר להרחיב את הפונקציה שתכניס מטאדאטה ל-PostgreSQL, לחשב סטטיסטיקות, לסווג אזורים וכו'.

טכנולוגיות בשימוש ולמה

Terraform – תשתית כקוד. כל התשתית (VPC, Security Groups, EC2, RDS, S3, Lambda, IAM) נבנית אוטומטית ומנוהלת בקוד אחד.

AWS EC2 – מכונות הרצה. אחת ציבורית שמגישה UI ודשבורד, אחת פרטית לעיבוד מאובטח.

AWS S3 – אזור נחיתה לנתונים גולמיים (Raw Data Landing Zone).

AWS Lambda – טריגר אוטומטי על כל קובץ חדש. זה מכין אותנו לעיבוד זרימת נתונים אמיתי.

AWS RDS (PostgreSQL) – מסד נתונים מנוהל, לשמירת תוצאות מעובדות בצורה יציבה ובטוחה.

Docker + docker-compose – הרצה של WordPress ו-MapServer על ה-EC2 הציבורי בצורה נשלטת.

CloudWatch Logs – ניטור ובקרה. אפשר לראות שכל האירועים אכן קורים, ולא רק "לסמוך".

מה שמרימים פה זה לא רק מכונה עם אתר, אלא סביבת עבודה מלאה:

אזור ציבורי להצגה ללקוח/עסק.

אזור פרטי מאובטח לניתוח נתונים ולעבודה של מפתחים/אנליסטים.

צינור אוטומטי לבליעת קבצים חדשים והפעלת תהליך עיבוד (סנסור מבוסס אירוע).

מסד נתונים מנוהל לשמירת המידע המעובד.

הכול מוגדר כ-Infrastructure as Code ב-Terraform, והכול ניתן לשחזור.
