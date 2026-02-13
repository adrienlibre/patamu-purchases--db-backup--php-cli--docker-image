# UPGRADES

This file contains the upgrades' log of the **Laravel** app.

## 20230801

- First commit

## 20240407

- Adding environment variables:
  - `010--app` => **ALLOWED_IPS**, **PATAMU_ORIGIN**.
  - `110--patamu` => **BANK_TRANSFER_COMPANY_NAME**, **BANK_TRANSFER_ACCOUNT_IBAN**, **BANK_TRANSFER_ACCOUNT_BIC**, **BANK_TRANSFER_ACCOUNT_BANK_NAME**.

## 20240412

- Adding environment variables:
  - `110--patamu` => **PATAMU_EMAIL_SUPPORT**, **PATAMU_EMAIL_INVOICE**.

## 20240522

- Adding environment variables:
  - `100--patamu` => **JWT_SECRET**.
- Rename enviroment variables' files:
  - `110--aws`.
  - `120--patamu`.
- Changes to adapt code to Laravel 11.x.

## 20240604

- Improving `AllowedIps` *middleware*. Now it takes into account the **ip** set at header's `X-Forwarded-For`, which is used by **Application Load Balancers** to set the original **ip** making the request.

## 20240605

- Improving `UpdateUserDataDuringPurchase` *middleware*. Now the check on addresses' changes take into account null values.
- Do a *cast* to **int** on `PayPalHelper->getDelayBetweenJobRetries` when consuming *config* variable `supported_payment_platforms.paypal.delay_between_job_retries`.

## 20240611

- Improving `GeneratePaymentUrlPost` *middleware*. Check that the **country** exists in the **json**'s request before validating it.
- Fix `ErrorPost` **api** and **webapp** *middlewares*. They wrongly check for a port on the urls on every situations, when it's only required on local development.
- **PayPal** requires a country for the billing addresses on its orders. In case the user hasn't entered the country in his address of residence (on **Patamu** webapp), the country is guessed so the **PayPal** order could be created. We use the purchase country, which is determined by the country dropdown on **Patamu**'s purchase page (used for VAT purpouses).

## 20240614

- Add legal **PayPal** information on the **Checkout** page.
- Add **Iubenda** cookie consent's *popup*.

## 20240619

- Improving `NotifyPurchaseSuccess` *job*. Add the response error's body to the **Purchase** log.

## 20240812

- Fix `PayPalExceptionManager`. The function `getLogData`'s parameter `$status` can be **string** or **array**.

## 20250206

- Log user on every action taken on the db.
- Fix user token handling: remove session, implement refresh and invalidate api endpoints.
- Fix `PayPalExceptionManager`. The function `getLogData`'s parameter `$restApiUrl` can be **string** or **null**.
- Adding environment variables:
  - `070--queue` => **DB_QUEUE**.
- Rename enviroment variable at `050--cache`:
  - from `CACHE_DRIVER` TO `CACHE_STORE`.

## 20250212

- Adapt code to Laravel 11 architecture.

## 20250219

- Artisan command to execute `composer audit`.
- Abstract mailables to a Base class to handle mail properties (to, cc, bcc).
- Improving `Api/ValidateRequest/ErrorPost.php` middleware. Allow strings of 1024 for field `payPalSdkMessage`.

## 20250314

- Fix on the command `ComposerAuditCommand` to handle the `composer audit` output.
- Improvements on emails `ComposerAuditIssuesDetected` and `ComposerAuditFailed`. Make them more readables.

## 20250326

- Upgrade to Laravel 12.
- Upgrade php packages.
- Fix component `Pages/BankTransferInformation.vue` (`ButtonCancelPurchase` markup).
- Fix component `Components/PayPalCardForm.vue` (import PayPal classes in the right way).
- Improve component `Components/PurchaseInformation.vue` (html markup; use `tbody` inside `table` and place `tr` elements there).
- Upgrade Tailwind (adapt code to the new 4 version).
- Upgrade Inertia.js.
- Prevent back button to Checkout page when the user is on Error or Complete pages.
- Replace Twitter with X.
- Fix `NotifyToPatamuFailedUser` mailable. Use the email of the user.
- Fix `WebApp` controller. Pass *language* to **Complete** page (vue component).

---

## UPGRADES ON PRODUCTION (since 2025/06/02)

## 202505271354

- Set default values to build arguments on the **Dockerfile**.

## 202505271354-r4

- Change `.env` variable `PAYPAL_CURL_TIMEOUT` to **10** seconds. There has been timeout errors (cURL error 28) trying to generate **PayPal Client tokens**.

## 202506031552-r0

- Use **PayPal Access Token** instead of **Client Token** (here has been timeout errors requesting the **Client Token**, and the **Access Token** is enough).

## 202506031552-r1

- `LOG_CHANNEL` was not set on `.env`, so it had the default value `daily`. Set it to `stack`, so errors could be reported to **BugSnag**.

## 202506050931-r0

- Create the exception `App\Exceptions\Logable\PayPal\CaptureDeclinedCardRetryException`.

## 202506051234-r0

- Fix **timeout** on frontend. On **202505271354-r4** we had increased the timeout for **PayPal** requests on *backend* to **10** seconds, while **Axios** on *frontend* was unchanged at **8** seconds. So errors on *frontend* happen before the real **PayPal** exceptions could happen on the *backend*.
- Fix error on `app/Http/Middleware/Api/ValidateRequest/ErrorPost.php`. Field `responseText` can be `null`; there's a **Laravel** *middleware* at place that converts empty strings to `null`, so we have to allow them.
- Improve the handling of connection errors on *middleware* `Api\PayPal\CreateOrderCard`; new exceptions created: `PayPalOrderCreateRequestConnectionRefusedException`, `PayPalOrderCreateRequestDnsResolutionException` and `PayPalOrderCreateRequestDnsResolutionException`.
- fix retrieval of language on exceptions `PayPalAccessTokenRequestConnectionRefusedException`, `PayPalAccessTokenRequestDnsResolutionException` and `PayPalAccessTokenRequestUnhandledConnectionException`.

## 202506070806-r0

- Fix an error on `App\Http\Controllers\ApiPatamu`, function `addressHasChanged`. It compares addresses and expected both *old* and *new* addresses being **strings**. The *old* address could be also `null`.

## 202506131219-r0

- Fix on `App\Http\Middleware\ApiPatamu\PayPal\PrepareRequest\CompletePurchasePost`. I used a `get_class` on a variable that could be `null`, which throws an exception.
- ***IMPORTANT*** fix on `App\Http\Middleware\WebApp\UserToken`. I computed wrongly the reamining seconds passed to the *frontend* for a user token to expire... I did a substraction between `jwt.ttl` (expiration time) and `jwt.jwt_safe_time_before_expiration` (custom variable to safely expire the token prior `jwt.ttl`). So, as in **Production**, we had a `jwt.ttl` of **10 minutes**, and a `jwt.jwt_safe_time_before_expiration` of **11 minutes**, it meant I passed to the *frontend* that the **User Token** has to **expire every minute**. The correct value is simply passing the value of `jwt.jwt_safe_time_before_expiration` to the *frontend*.

## 202506131712-r0

- Discounts are not tied anymore to the existance of a **discount id** (like a **coupon**). There were discounts in **Akeeba** that weren't tied to a **coupon** (for example, upgrading to ***Professional*** on the days after a renewal to ***Advanced*** is made). If no **coupon** existed, the discounts were discarded and the totals were wrong. It lead to **PayPal Rest Api** errors (`AMOUNT_MISMATCH`).

## 202506151338-r0

- Fix **Internal Error Codes** for the following exceptions:
  - `PayPalOrderCaptureRequestTimeoutException`
  - `PayPalOrderCaptureRequestUnknownException`
  - `PayPalOrderCreateRequestConnectionRefusedException`
  - `PayPalOrderCreateRequestDnsResolutionException`
  - `PayPalOrderCreateRequestTimeoutException`
  - `PayPalOrderCreateRequestUnhandledConnectionException`
  - `PayPalOrderCreateRequestUnknownException`
- Improve the handling of connection errors on *middleware* `Api\PayPal\CapturePayment`; new exceptions created: `PayPalOrderCaptureRequestConnectionRefusedException`, `PayPalOrderCaptureRequestDnsResolutionException` and `PayPalOrderCaptureRequestUnhandledConnectionException`.
- Change `.env` variable `PAYPAL_CURL_TIMEOUT` to **15** seconds. Set accordingly timeout for **Axios** requests on the *frontend* to **18** seconds.

## 202506151922-r0

- On **202506131712-r0** I introduced a bug when decoupling *discounts* from *coupons*. Because of a bad *copy-paste*, I didn't initialize the field `purchase.discount_amount`.

## 202506230549-r0

- Allow all payment types **PayPal** allows: **American Express** cards seems to work in Italy, but we discarded them thinking they were forbidden. We only allowed **Visa** and **Mastercard**. Now we allow all possible cards **PayPal** can handle, *no matter they are allowed in Italy or not*; a proper error message is rendered if they can't be used. Same goes for payment sources. We only allowed **Cards** or **PayPal accounts**, now we allow everything **PayPal** accepts (again, *no matter it's allowed in Italy or not*).

## 202506230654-r0

- **PayPal** communication issues have been resolved. The *timeout* errors were incorrectly attributed to **PayPal**, but the actual cause was security group rules blocking connections to **PayPal CDNs**. Updated the `.env` variable `PAYPAL_CURL_TIMEOUT` to **8** seconds and set the Axios timeout on the *frontend* to **11** seconds accordingly.

## 202506241940-r0

- Improve `ConnectionException` handling on processes: refund, create **PayPal** order using **PayPal** account, retieve **PayPal** order details from **Rest API**.
- Fix some exceptions `INTERNAL_ERROR_CODE`.

## 202506251022-r0

- Create the exception `App\Exceptions\Logable\PayPal\CaptureDeclinedCardSecurityViolationException`.

## 202506251458-r0

- Fix class `LogDataErrorPayPalSdk`. The class property `$authenticationResult` could be an `object` or a `string`.

## 202506261302-r0

> ***NOTE: This version has been discarded. I wrongly assumed that it's ok making huge urls (i added whole error infomration as an ecrypted parameter in the url). The WAF discarded error urls.***

### MAJOR UPDATE INVOLVING THE FRONTEND

Previously, errors occurring on the *frontend* triggered a `POST` request to a **web error route**. This route rendered a friendly error page, guiding the user on possible next steps. However, if the user refreshed the browser, a `GET` request was sent to the same error route, which expected a `POST`. This mismatch triggered an **exception**, resulting in a cryptic error message with no guidance, as our application is designed to show such errors only to malicious actors accessing invalid routes.

Now, when an error occurs, the server returns a **URL** to the *frontend* with the error encrypted as a parameter on the **web error route**. This route now accepts `GET` requests. As a result, when the error is rendered in the *frontend*, users can safely refresh the browser and will continue to see the same error message until they follow the actions provided on the error.

**Button texts have also been updated to better guide users**. For example, where we previously used ***Refresh page*** to suggest retrying a purchase, we now use ***Retry purchase***. This change encourages users to follow the provided actions rather than relying on the browser's refresh button.

## 202506261337-r0

> ***NOTE: This version has been discarded. It's a follow up of the wrong 202506261302-r0 version.***

- Add a new **PayPal Order** issue `UNPROCESSABLE_ENTITY`. ***Note: Only seen in development while using an invalid Diners Club card.***

## 202506261745-r0

Updated ***capture*** enums to reflect the latest values supported by **PayPal**.

Due to frequent changes in the allowed values for **PayPal** Processor Response's **Code**, **AVS**, and **CVV**, the related fields in the `paypal_capture` table are no longer defined as enums.

## 202506271236-r0

### MAJOR UPDATE INVOLVING THE FRONTEND (Error Caching)

- Previously, errors occurring on the *frontend* triggered a `POST` request to a **web error route**. This route rendered a friendly error page, guiding the user on possible next steps. However, if the user refreshed the browser, a `GET` request was sent to the same error route, which expected a `POST`. This mismatch triggered an **exception**, resulting in a cryptic error message with no guidance, as our application is designed to show such errors only to malicious actors accessing invalid routes.

    Now, when an error occurs, it is stored in cache for 3600 seconds (1 hour); this is the default value, it can be changed through environment variable `CACHE_TTL_ERROR`. Then the server returns an **URL** to the *frontend* with the error cache key encrypted as a parameter on the **web error route**. This route now accepts `GET` requests. As a result, when the error is rendered in the *frontend*, users can safely refresh the browser and will continue to see the same error message until they follow the actions provided on the error.

- **Button texts have also been updated to better guide users**. For example, where we previously used ***Refresh page*** to suggest retrying a purchase, we now use ***Retry purchase***. This change encourages users to follow the provided actions rather than relying on the browser's refresh button.

- Add a new **PayPal Order** issue `UNPROCESSABLE_ENTITY`. ***Note: Only seen in development while using an invalid Diners Club card.***

- Improvements on Exceptions:
  - Clean.
  - Many have a user property which already exists in `BaseException`.
  - Remove unnecessary transation `paypal.exceptions.request_unknown.error`.

## 202506282212-r0

- Add `CACHE_TTL_ERROR` to `.env` file.
- Prevent exception `CaptureDeclinedCardSecurityViolationException` being rendered.
- Allow all countries. Previously, we used a list from PayPal (<https://developer.paypal.com/reference/country-codes/>) that included only **countries where PayPal accounts could make purchases via the REST API**. For example, a user from **Lebanon was unable to complete a purchase** because the `GeneratePaymentUrlPost` *middleware* blocked the request (**Lebanon** was not present in our `countries` table). Now, we allow all countries, and any necessary restrictions will be enforced by the **PayPal REST Api**.

## 202506291652-r0

- Prevent some deprecation messages.
- Create the exception `App\Exceptions\Logable\PayPal\CaptureDeclinedInstrumentDeclinedException`.

## 202507101150-r0

- Handle `ConnectionException` errors on job `NotifyPurchaseSuccess`.

## 202507101439-r0

- Create exceptions `CaptureDeclinedCardInvalidTerminalException` and `CaptureDeclinedCardScaRequiredException`.
- Don't report exception `CaptureDeclinedCardRetryException`.

## 202507101633-r0

- Set locale to user's language when sending email `NotifyToPatamuFailedUser`.
- Improve the message of the email `NotifyToPatamuFailedUser` to be more specific and reassuring.

## 202507151219-r0

- implement endpoint `api-patamu/accounting/generate-invoice-data-report/{date_from}/{date_to}` to generate the report that will be use to generate invoices (it only contain the successful **PayPal** purchases). This endpoint will be consumed by **Patamu**.
- change vite configuration to make local development work.

## 202507171259-r0

- Implement `Tinkerable` trait to be used for **Models**.
- Create a scoped **Tinker**-*like* method to retrieve purchases on `Purchases`.

## 202507171820-r0

- Improve invoices' report data:

  - `address` is a **JSON** column and its data has been splitted into columns `address_street`, `address_city`, `address_province` and `address_postal_code`.
  - `country` column is set to `IT` when **Fiscal Code** is present (***note: the computation of the field should be improved in the future***).
  - the purchase date format on the report has changed to `d/m/Y`.

## 202507231123-r0

- Add **env** variable `LOG_DAILY_RETENTION_DAYS` into `020--log`.
- Update `config/logging` to make *daily* configuration consume this created `LOG_DAILY_RETENTION_DAYS` **env** varriable.

## 202507231339-r0

- Fix query on model `Purchase::getUserInvoiceDataByDateRange`. It has to retrieve the latest *orderable*, it retrieved all of them.
- Improve generated report on endpoint `api-patamu/accounting/generate-invoice-data-report/{date_from}/{date_to}`.

## 202507241217-r0

> ***Note: this is the*** Step 1 ***of the*** 202507241217 ***upgrade. First we need the migration take place before we can use the field*** `paypal_captures.paypal_name`***.***

- Migration to add the column `paypal_captures.paypal_name`.

## 202507241217-r1

> ***Note: this is the*** Step 2 ***of the*** 202507241217 ***upgrade.***

- Store the name of the user making the purchase into the field `paypal_captures.paypal_name`. If he has used a **card**, it will be the name on the card, if he has used a **PayPal account**, the name related to it.

## 202507252030-r0

- Improve invoices' report data:

  - Tab info matching what's requested by **Daniela**.
  - Consolidated into single `generateInvoiceReport` function with 4 tabs.
  - Added red highlighting for incomplete bank transfers with visual legends.
  - Enhanced styling with proper cell spacing and no visible borders.
  - Fixed decimal formatting consistency across all tabs.
  - Tab **Bank Transfer**:
        - **Bank transfer** purchases only (`order-completed`, `order-created` status).
  - Tab **PayPal**:
        - **PayPal** purchases only (`order-notified` status).
  - Tab **Combined**:
        - Union of **Bank Transfer** + **PayPal** data.
  - Tab **Combined (Extended)**:
        - Same as **Combined** + comprehensive address information.

## 202508251144-r0

- Implement comprehensive error handling for **PayPal SDK** script loading failures by:
  - Adding a new enum value `ErrorFrontendPayPalScriptNotLoaded` to track when the **PayPal JavaScript SDK** fails to load.
  - Updated database schema with a migration to add the new purchase status enum value `error-frontend-paypal-script-not-loaded`.
  - Enhanced frontend error handling in the **Checkout** component to catch and log script loading errors.
  - Updated backend to properly handle the new error type.

## 202509011626-r0

- Insert of a missing country on `countries` table (**Turkey**).
- Implement changes to `users` table document fields: expand tracking from only **Italian Fiscal Codes** to include **Passports from non-Italian countries** as well (from `users.document_fiscal_code` to `users.document_type` and `users.document_number`).

## 202509021108-r0

- Updated reports to display enhanced document fields. Changed from showing only **fiscal code** to displaying **document country**, **type**, and **number**.

## 202509081714-r0

- Add `paypal_captures.paypal_company_name`: stores the business name when the buyer pays with a **PayPal business account**. This value is used in **PayPal invoicing exports**; include it in our reports to match **PayPal** invoices.

## 202509090953-r0

- Improved reports for **PayPal account** purchases: now, if a **business name** is available, it is displayed; otherwise, the **user name** associated with the **PayPal account** is shown.

## 202509170652-r0

- Reports data is filtered by Italian local dates (data is stored in UTC).

## 202510031223-r0

- Create an endpoint to allow updating **Purchase** data related to **company invoicing** (`api-patamu/purchase/update/{purchase_type}/{purchase_subtype}/{patamu_purchase_id}`).

## 202510061812-r0

- Create report tab **Fattura non Corrispondenti**.
- Bind column **Numero Fattura** from tabs **Fattura per Tutti** and **Fattura non Corrispondenti** (when an invoice number is set in tab **Fattura per Tutti**, it is automatically copied on tab **Fattura non Corrispondenti**).
- Move the report generation code into a job named `GenerateInvoiceReportJob`.

## 202510071000-r0

- Limit the date range for report generation. Configurable via two parameters (can be set via environment variables): **unit** (`days` or `months`) and value (integer).

## 202510080946-r0

- Migration to add ability `can-do-accounting` to the **personal access tokens** of users **Adriano Bonforti**, **Daniela Castrataro**, **Lluís Aznar**.

## 202510081231-r0

- Split `FatturaPerTutti` tab into `FatturaPerTuttiPayPal` and `FatturaPerTuttiBankTransfer`. The original `FatturaPerTutti` will only contain **PayPal** data. **Bank transfers** are uncertain transactions, so they are kept isolated in a separate tab. If the user analyzing the report determines that bank transfer data should be included in the invoicing process, it can be copied to the main `FatturaPerTutti` tab.

## 202510091943-r0

- Handle pending refunds. A refund remains in pending state when the customer's account is funded through an eCheck that has not yet cleared.
- Create a command `ProcessPendingRefundsCommand` to check the status of pending refunds. This command runs automatically every day at 2:00 AM.

## 202510092056-r0

- Create tinker function `tinkerPurchaseLogs` on `Purchase` model to output all logs related to a purchase.
- Improve tinker function `scopeTinkerPurchases` on `Purchase` model to order purchases by ID in descending order.

## 202510100950-r0

- Fix `Logable` trait: the function `saveLogData` consumed by models now accepts a mixed parameter allowing both `LogData` and `LogDataCommand` types.
- Fix command `ProcessPendingRefundsCommand`: force requests to **PayPal Rest API** for each purchase parsed. Previously, if there were multiple purchases to parse, the first one was cached and the following purchases were not checked.

## 202510131136-r0

- Upgrade PHP container and all its software:
  - PHP version updated from **8.4.7** to **8.4.13**
- **Major Composer libraries update:**
  - `justinrainbow/json-schema` (from **^5.2** to **^6.6**)
  - `phpoffice/phpspreadsheet` (from **^4.4** to **^5.1**)

    > *Note: this library upgrade addresses a security vulnerability:* **CVE-2025-54370** *(PhpSpreadsheet vulnerable to SSRF when reading and displaying a processed HTML document in the browser)*

  - `phpunit/phpunit` (from **^11.5.3** to **^12.4**)
- **Major frontend libraries update:**
  - `vite` (from **^6.0.11** to **^7.1.9**)
  - `@fortawesome/fontawesome-svg-core` (from **^6.4.0** to **^7.1.0**)
  - `@fortawesome/free-brands-svg-icons` (from **^6.4.0** to **^7.1.0**)
  - `@fortawesome/free-regular-svg-icons` (from **^6.4.0** to **^7.1.0**)
  - `@fortawesome/free-solid-svg-icons` (from **^6.4.0** to **^7.1.0**)
  - `@paypal/paypal-js` (from **^8.0.2** to **^9.0.1**)
  - `@vitejs/plugin-vue` (from **^5** to **^6**)

## 202510131621-r0

- ***Fattura per Tutti*** tabs' addresses now have the same behavior as the addresses on other tabs.
- Fix column **PEC**: retrieve its value from `company_invoice_data`, as it is not related to `tax_number`.

## 202510141302-r0

- Fix ***Fattura per Tutti*** tabs' **Nazione** column: if `company_invoice_data` exists, **Nazione** should display the country from this data. If `company_invoice_data` does not exist, the user is the one being invoiced, and **Nazione** should display the `document_country` (the country where the fiscal code or passport was issued).

## 202510171649-r0

### Backend Changes

- Fixed `ErrorPost` middleware by properly implementing what was previously left incomplete: replaced the generic `payPalSdkMessage` field with two specific error fields:
  - `payPalSdkErrorConfirmPaymentSource` - for **PayPal SDK** confirm payment source errors (with comprehensive JSON schema validation)
  - `payPalSdkErrorInternal` - for **PayPal SDK** internal errors (string, max 1024 characters)
- Reorganized validation field groups and removed redundant checks for single-field groups.

### Frontend Changes

- Improved **TypeScript** type safety across multiple files to eliminate implicit `any` type errors:
  - `FrontendErrorManager.ts`: Added strict literal types and generic type constraints
  - `PayPalCardForm.vue`: Fixed return types for `getFieldName()` and `getErrorMessage()` functions
  - `ApiCallbacks.ts`: Fixed **PayPal** type imports by removing deep path imports

## 202510231139-r0

- Implement **PayPal Negative Testing**. It involves the creation of some variables on enviroment variable file `120--patamu`:
  - `PAYPAL_NEGATIVE_TESTING_ENABLED`
  - `PAYPAL_NEGATIVE_TESTING_CREATE_ORDER`
  - `PAYPAL_NEGATIVE_TESTING_ORDER_DETAILS`
  - `PAYPAL_NEGATIVE_TESTING_CAPTURE_ORDER`

    > ***Warning: use only this functionallity in local development***

- Create the exception `App\Exceptions\Logable\PayPal\TransactionRefusedException`.

## 202510231354-r0

- Fix validation middlewares that were throwing regex format errors when validating the encrypted parameter in the URL.

## 202510241733-r0

### 1. Short-Circuit Middleware for Completed Purchases

- **Problem**: PayPal SDK timeout caused orphaned error requests that corrupted completed purchase status
- **Solution**: Created `PreventErrorOnCompletedPurchase` middleware
  - Short-circuits `/api/error/{purchase}` when purchase is already completed
  - Returns `{shortcircuit: true}` response instead of processing error
  - Comprehensive logging for monitoring
  - Frontend: Updated `FrontendErrorManager` and `ApiCallbacks` to detect and ignore short-circuit responses
- **Result**: Completed purchases stay completed, transparent to user experience

### 2. PHPUnit Test Environment Setup

- **Database Configuration**:
  - Created dedicated `phpunit` database connection in `database.php`
  - Configured `phpunit.xml` to use `phpunit` database via `DB_CONNECTION=phpunit`
  - Isolated test data from development database
- **Migration Script**:
  - Created `d_migrate_fresh_skip` script to handle country data conflicts
  - Skips two country-insert migrations during `migrate:fresh`

### 3. Seeders Enhancement

- **Environment-Specific Database Mapping**:
  - Updated `DatabaseSeeder` to automatically map env to database connection
  - `development`/`production` → `mysql`, `phpunit`/`testing` → `phpunit`
- **User Seeders Consistency**:
  - Standardized `PhpunitUsersSeeder` and `ProductionUsersSeeder` with `DevelopmentUsersSeeder`
  - All use `document_type` + `document_number` (replaced `document_fiscal_code`)

### 4. Factory Pattern Implementation

- **UserFactory**: Enhanced with Faker support while maintaining seeder compatibility
- **PurchaseFactory**:
  - Full factory with proper `purchase_type` → `purchase_subtype` → `product` relationships
  - Automatic tax/total calculations
  - Product-specific methods (`singleTimestamp()`, `professional()`, etc.)
  - Status methods (`orderCompleted()`, `orderNotified()`, etc.)
- **PayPal Structure Factories**:
  - `PayPalOrderFactory` with status states
  - `PayPalCaptureFactory` with payment source types
  - `PayPalOrderActionFactory` and `OrderFactory` for pivot tables
  - `withPayPalOrder()` helper creates full relationship chain

### 5. Comprehensive Test Suite

- **Feature Test**: `ErrorEndpointShortCircuitTest`
  - Tests short-circuit for completed purchases (no error processing)
  - Tests normal error flow for non-completed purchases
  - Uses JWT authentication
  - Full PayPal order structure via factories
- **Documentation**: Updated `docker-readme.md` with testing guide and best practices

- **Code Quality Improvements**
Fixed redundant shortcircuit check in FrontendErrorManager.catch() block
Improved validation middleware to include value/length in error messages

## 202510271728-r0

### FatturaPerTutti Tab Fix Summary

### **Problem Identified**

- **Data structure mismatch**: `FatturaPerTutti` expected per-unit amounts, but was receiving total amounts
- **Example**: With `quantity=2` and `amount=16.4`, `FatturaPerTutti` interpreted `16.4` as per-unit (calculating total as `32.8`), when it should have been `16.4` per unit

### **Changes Made**

#### 1. Updated Purchase Model Queries

- Modified all invoice data queries to calculate per-unit amounts instead of totals
- Changed from `total_amount` to `price_unit - discount_per_unit_amount`

#### 2. Updated Excel Report Tabs

- 6 files updated to match new column names:
  - `Combined.php`
  - `CombinedExtended.php`
  - `PayPal.php`
  - `PayPalExtended.php`
  - `BankTransfer.php`
  - `BankTransferExtended.php`
- Changed column mappings:
  - `gross` → `gross_per_unit`
  - `net` → `net_per_unit`
  - `gross_minus_fee` → `gross_total_minus_fee`
- Updated headers for clarity:
  - `GROSS` → `GROSS (PER UNIT)`
  - `NET` → `NET (PER UNIT)`
  - `GROSS (MINUS FEE)` → `GROSS TOTAL (MINUS FEE)`

#### 3. Fixed Null Handling

- Added `COALESCE()` to handle null discount/tax amounts
- Prevents SQL errors when discount or tax fields are null
- Pattern: `COALESCE(purchases.discount_per_unit_amount, 0)`

#### 4. Fixed Decimal Precision

- Added `ROUND(..., 2)` to all calculated amounts
- Prevents floating-point precision issues from `FLOAT` columns
- Ensures exactly 2 decimal places in all monetary values
- Applied to: `gross_per_unit`, `net_per_unit`, `subtotal_amount`, `gross_total_minus_fee`

## 202510281156-r0

- **PayPal Error Message Fix**: Corrected string concatenation logic in `LogDataErrorPayPalDetailed` where missing parentheses caused malformed warning messages showing **", issue: "** when issue was `null`.

- **JSON Schema Validation Improvement**: Enhanced JSON schema validation error reporting across 6 middleware files (`UpdateUserDataPost`, `ErrorPost`, `GeneratePaymentUrlPost`, `UpdatePurchaseDataPost`, `BankTransfer/CreatePurchasePost`, `PayPal/CreatePurchasePost`) to include property paths in validation errors, changing generic messages like ***Must be at most 10 characters long*** to specific ones like ***postal_code: Must be at most 10 characters long***.

## 202511031740-r0

- `UpdatePurchaseDataPost` -> fix validation of **SDI**.

## 202511041224-r0

- Tabs `BankTransferExtended`, `PayPalExtended`: Only remove letters from the **Postal Code** when the country is Italy.

## 202511121335-r0

- Tabs of type `BaseFatturaPerTutti` now add a trailing single quote to the **P. IVA** field to prevent removal of trailing zeroes when exporting to CSV.

## 202511190933-r0

- Enhanced the tinker command used to retrieve successful purchases by adding information about purchase quantity (relevant for one-time purchases) and associated discounts.

## 202512021701-r0

- Created endpoint `api-patamu/user/switch-purchases-owner/{author}` to transfer purchases from one user to another and update the user profile when needed.

## 202512051654-r0

- Create the exceptions:
  - `App\Exceptions\Logable\PayPal\CaptureDeclinedCardRestrictedOrInactiveException`.
  - `App\Exceptions\Logable\PayPal\CaptureDeclinedCardUpdatedAccountException`.
  - `App\Exceptions\Logable\PayPal\CaptureDeclinedCardAmountExceededException`.

## 202601071007-r0

- Support PayPal internal 5xx errors (`INTERNAL_SERVER_ERROR`, `SERVICE_UNAVAILABLE`).
- Major refactor to simplify error handling, clarifying the separation between frontend errors and those produced at the backend while connecting to the PayPal REST API. Key improvements include:
  - Updated purchase statuses to cover all error types
  - Enhanced frontend error type differentiation
  - Simplified `LogData` class dependencies (reduced from 7 nested classes)
  - Add error schemas

## 202601081056-r0

- Don't report exception `\App\Exceptions\Application\ErrorInCacheHasExpiredException`. Errors are cached for 1 hour, which is sufficient time for users to see them during normal flow. If this exception occurs after the 1-hour expiration, it likely indicates the user is loading the error page from browser history.

## 202601081125-r0

- Don't report exception `\App\Exceptions\Application\PurchaseCompletedSuccessfullyWebException`. It's not concerning when users attempt to load the Checkout page of an already completed purchase.

## 202601081806-r0

- Fix communication bug: when generating the payload to post error data to our api error endpoint, always post data as an object, and handle it properly on ErrorPost middlewares.

## 202601081806-r1

- Upgrade **Php** to `8.4.16` to prevent security vulnerability `CVE-2025-14177`.

## 202601131706-r0

- Enhanced Bank Transfer data with information about manual intervention.

## 202601211123-r0

- Add file `public/health-check.php` to completely bypass the **Laravel** framework. It will be used by the ECS service's health checks.

## 202601211156-r0

- `routes/web.php` -> clean route `health-check`.

## 202601211525-r0

- Upgrade package `adrienlibre/db-backup` to **3.0.1**. This new release adds timing information on sensitive jobs that take more time to execute and are memory consuming.

## 202601221722-r0

- **Improved `SdkUnknownException` Handling**: Unknown **PayPal SDK** errors now log complete error data to Laravel's log file for debugging and implementing proper exception handling.

- **Database Save Failure Logging**: Failures when saving to `Log` and `Error` models are now logged to Laravel's log file to detect issues with the logging infrastructure itself.

## 202601271556-r0

- Create the exception `App\Exceptions\Logable\PayPal\CaptureDeclinedCardInvalidMerchantException`.
- Implement a system to test processor responses; PayPal negative testing only covers PayPal-specific errors.

## 202602121031-r0

- Remove database backup commands and uninstall the `adrienlibre/db-backup` package.
