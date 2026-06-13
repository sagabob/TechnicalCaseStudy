# Azure Bicep — Interview Question Bank

A study guide covering Bicep from fundamentals to advanced topics, with concise model answers. Use the questions to self-test; the answers are deliberately tight so you can expand on them in your own words during an interview.

---

## 1. Fundamentals

**1. What is Bicep?**
A domain-specific language (DSL) for declaratively deploying Azure resources. It's a transparent abstraction over ARM templates — Bicep files transpile to ARM JSON, and anything ARM can express, Bicep can too.

**2. How does Bicep relate to ARM templates?**
Bicep is a higher-level authoring layer. `az bicep build` compiles a `.bicep` file into an ARM JSON template, which is what Azure Resource Manager actually deploys. There's no separate runtime — Azure doesn't "run Bicep," it runs the compiled ARM JSON.

**3. Why use Bicep over raw ARM JSON?**
Cleaner, less verbose syntax; no JSON noise (commas, brackets, escaped strings); simpler module system; automatic dependency management via symbolic references; first-class tooling (IntelliSense, validation, linting); and no state file to manage (unlike Terraform).

**4. Is Bicep idempotent?**
Yes. Deploying the same template repeatedly produces the same result — ARM reconciles desired state against actual state, creating or updating resources as needed rather than duplicating them.

**5. What's the file extension and how do you deploy a Bicep file?**
`.bicep`. Deploy with the Azure CLI (`az deployment group create --template-file main.bicep`) or PowerShell (`New-AzResourceGroupDeployment`). The CLI compiles to ARM automatically.

**6. How do you convert an existing ARM template to Bicep, and vice versa?**
`az bicep decompile --file template.json` converts ARM JSON to Bicep (best-effort — review the output). `az bicep build --file main.bicep` compiles Bicep to ARM JSON.

---

## 2. Language Building Blocks

**7. How do you declare a resource in Bicep?**
```bicep
resource sa 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'mystorageacct'
  location: resourceGroup().location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
}
```
`sa` is the symbolic name (used to reference the resource in code), followed by the resource type and API version.

**8. What is a symbolic name and why does it matter?**
The local identifier you assign to a resource or module. Referencing it (e.g. `sa.id`) creates an implicit dependency, so Bicep orders deployments correctly without manual `dependsOn`.

**9. What's the difference between `param`, `var`, and `output`?**
`param` is an input supplied at deployment time (overridable, can have defaults). `var` is a computed value internal to the template (not overridable). `output` returns a value from the deployment for use by callers or other tooling.

**10. How do you give a parameter a default value and constraints?**
```bicep
@description('Environment name')
@allowed(['dev', 'test', 'prod'])
param environment string = 'dev'
```
Decorators like `@allowed`, `@minLength`, `@maxLength`, `@minValue`, `@maxValue`, and `@description` enforce constraints and document intent.

**11. How do you handle secrets in parameters?**
Mark them with `@secure()`. Secure parameters aren't logged or shown in deployment history. Better still, reference Key Vault directly so the secret value never appears in the template or command line.

**12. How does string interpolation work in Bicep?**
With `${}` syntax: `name: 'sa${uniqueString(resourceGroup().id)}'`. Cleaner than ARM's `concat()`.

**13. How do you write a conditional (ternary) expression?**
`sku: environment == 'prod' ? 'Premium_LRS' : 'Standard_LRS'`.

---

## 3. Modules

**14. What is a module in Bicep?**
A Bicep file consumed by another Bicep file, enabling reuse and composition. You reference it with the `module` keyword and pass parameters in / read outputs back.
```bicep
module storage 'modules/storage.bicep' = {
  name: 'storageDeploy'
  params: { location: location }
}
```

**15. How do you pass values between modules?**
A module exposes `output` values; the parent reads them via the symbolic name: `storage.outputs.storageId`. Passing one module's output as another's input creates an implicit dependency that orders them correctly.

**16. Can a module deploy to a different scope than its parent?**
Yes. A module can target a different resource group, subscription, etc., via the `scope` property — useful for cross-resource-group or subscription-level deployments.

**17. What is the Bicep module registry?**
A way to publish and share modules from an Azure Container Registry. You reference registry modules with a `br/` prefix (`br:myregistry.azurecr.io/modules/storage:v1`), promoting versioned, reusable infrastructure. Template Specs (`ts/`) serve a similar purpose using a native Azure resource.

---

## 4. Loops and Conditions

**18. How do you deploy multiple instances of a resource (loops)?**
With a `for` expression:
```bicep
resource sa 'Microsoft.Storage/storageAccounts@2023-01-01' = [for i in range(0, 3): {
  name: 'sa${i}'
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
}]
```
You can loop over arrays, ranges, or array items with their index: `[for (item, i) in items: {...}]`.

**19. How do you conditionally deploy a resource?**
With `if`:
```bicep
resource sa '...' = if (deployStorage) {
  name: 'mystorage'
  ...
}
```

**20. What does `@batchSize()` do?**
Controls how many instances of a looped resource deploy in parallel. By default looped resources deploy concurrently; `@batchSize(2)` limits it to two at a time (serial if set to 1), useful when there are ordering or throttling concerns.

**21. How do you reference one element of a resource loop?**
Index into the symbolic collection: `sa[0].id`.

---

## 5. Scopes and Deployment

**22. What deployment scopes does Bicep support?**
Resource group, subscription, management group, and tenant. You set the scope of a file with `targetScope = 'subscription'` (etc.). Default is resource group.

**23. How do you deploy a resource group itself with Bicep?**
At subscription scope: set `targetScope = 'subscription'`, declare a `Microsoft.Resources/resourceGroups` resource, then deploy resources into it via a module scoped to that resource group.

**24. What's the difference between incremental and complete deployment modes?**
Incremental (default) adds/updates resources in the template and leaves others untouched. Complete mode deletes resources in the resource group that aren't in the template. Complete is powerful but dangerous.

**25. What does `what-if` do?**
`az deployment group what-if` previews the changes a deployment would make — what gets created, modified, or deleted — without applying them. Essential for safe CI/CD.

---

## 6. Functions and Expressions

**26. How do you reference an existing (already-deployed) resource?**
With the `existing` keyword — you don't redeploy it, just get a typed reference to read its properties:
```bicep
resource kv 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: 'myvault'
}
```

**27. How do you read a Key Vault secret as a module parameter securely?**
Reference an `existing` Key Vault and use `getSecret()` when passing it to a module's `@secure()` parameter:
```bicep
params: { adminPassword: kv.getSecret('sqlAdminPassword') }
```
The value is resolved by ARM at deploy time and never exposed in logs.

**28. What are some commonly used Bicep functions?**
`resourceGroup()`, `subscription()`, `resourceId()`, `reference()`, `uniqueString()`, `guid()`, `concat()`, `union()`, `contains()`, `length()`, `range()`, and the load functions `loadTextContent()`, `loadJsonContent()`, `loadFileAsBase64()`.

**29. How do you create dependencies, and when do you need explicit `dependsOn`?**
Usually you don't — referencing another resource's property creates an implicit dependency. Use explicit `dependsOn` only when there's an ordering requirement with no property reference between the resources.

**30. What do `loadTextContent` and `loadJsonContent` do?**
They embed external file contents into the template at compile time — handy for scripts, config blobs, or sharing a single JSON config across templates.

---

## 7. Advanced Topics

**31. What are user-defined types in Bicep?**
The `type` keyword lets you define custom, reusable type definitions for parameters and variables (objects, unions, arrays), improving validation and self-documentation beyond primitive types.

**32. What are user-defined functions?**
The `func` keyword lets you define reusable expressions/functions within a Bicep file, reducing repetition of complex logic.

**33. What is `bicepconfig.json` used for?**
A configuration file that customizes the Bicep experience — linter rules and severity, module aliases for registries/template specs, and experimental feature flags.

**34. What is the Bicep linter?**
A built-in static-analysis tool that flags issues and anti-patterns (unused parameters, insecure defaults, hardcoded locations, etc.). Rules are configurable in `bicepconfig.json`.

**35. How does Bicep handle resource extensibility / non-Azure resources?**
Through `import` statements and provider extensions (e.g. Microsoft Graph, Kubernetes), letting Bicep manage some resources outside the core ARM control plane.

**36. How do deployment scripts work in Bicep?**
The `Microsoft.Resources/deploymentScripts` resource runs PowerShell or Azure CLI as part of a deployment for steps ARM can't express declaratively (e.g. generating certificates, calling APIs). They run in a container and can return outputs to the template.

---

## 8. Comparison Questions

**37. Bicep vs Terraform — key differences?**
Bicep is Azure-only and stateless (ARM tracks state in Azure); Terraform is multi-cloud and uses an explicit state file. Bicep gets day-one support for new Azure features; Terraform depends on provider updates. Terraform has a larger ecosystem and cross-cloud reach.

**38. Does Bicep have a state file like Terraform?**
No. Resource Manager maintains the source of truth in Azure itself, so there's no state file to store, lock, or secure.

**39. When might you still use ARM JSON over Bicep?**
Rarely now — mainly legacy pipelines, tooling that only consumes JSON, or auto-generated templates. Bicep is Microsoft's recommended authoring language for new work.

---

## 9. Scenario / Practical Questions

**40. How would you structure Bicep for multiple environments (dev/test/prod)?**
Keep one set of templates/modules and vary inputs per environment using parameter files (e.g. `dev.bicepparam`, `prod.bicepparam`), driving SKUs, counts, and feature flags from parameters rather than duplicating templates.

**41. How do you reuse infrastructure across teams or projects?**
Factor common pieces into modules and publish them to a Bicep registry (ACR) or Template Specs with semantic versioning, so consumers reference a pinned, tested version.

**42. How would you integrate Bicep into CI/CD?**
Lint and `build` on PR, run `what-if` against the target environment for review, then deploy on merge via `az deployment group create`. Use service principals / managed identities with least-privilege RBAC, and store parameter secrets in Key Vault.

**43. A deployment fails midway — what happens to already-created resources?**
In incremental mode, successfully created resources remain; ARM doesn't roll them back. Re-running the (idempotent) deployment after fixing the error reconciles to the desired state.

**44. How do you deploy a resource that depends on a resource in another resource group?**
Reference it with `existing` plus a `scope` pointing at the other resource group, or pass its resource ID in as a parameter.

**45. How do you avoid hardcoding the location?**
Default it to `resourceGroup().location` (or pass it as a parameter), so resources inherit the deployment's location rather than a fixed value.

---

## 10. Best-Practice Questions

**46. What are some Bicep authoring best practices?**
Parameterize anything environment-specific; rely on implicit dependencies; use modules for reuse; never hardcode secrets (use `@secure()` / Key Vault); pin API versions; enable the linter; prefer `uniqueString()` for globally unique names; and run `what-if` before deploying.

**47. How do you generate globally unique resource names?**
Combine a stable seed with `uniqueString()`, e.g. `'sa${uniqueString(resourceGroup().id)}'`, which produces a deterministic hash so redeployments keep the same name.

**48. How do you keep templates DRY?**
Extract repeated resources into modules, use loops instead of copy-paste, centralize shared values in variables, and use `loadJsonContent()` for shared config.

---

*Tip: in interviews, when asked "how would you do X," narrate the decision (why a module, why a parameter, why `existing`) rather than just reciting syntax — that's what distinguishes someone who has actually built with Bicep.*
