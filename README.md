# Artifacts

## Contract field enrichment

**Status: partial implementation, not an activation-ready scenario integration.**
The provider alias is implemented in the CDS source. The ABAP enrichment layer
and resolver contract are supplied, but a release-specific resolver implementing
`ISU_O_SCENARIO_AT_POD_GET` is deliberately **not** supplied: this repository has
no SAP runtime, function-module interface, or DDIC metadata with which to verify
its parameters, returned structures, installation-to-PoD lookup, or text source.
Do not treat the custom resolver interface as the SAP FM's signature.

### Fields and consumption

| Exposed field | Source |
| --- | --- |
| `ServiceProvider` | Alias of `I_UtilitiesContract.UtilitiesServiceProvider`; the existing `UtilitiesServiceProvider` remains available. No new provider-selection rule is introduced. |
| `SupplyScenario` | Application-layer resolver result, which must be obtained using `ISU_O_SCENARIO_AT_POD_GET` after resolving the installation's PoD at the requested date. |
| `SupplyScenarioDescription` | Description for that same scenario in the requested language (default: logon language), from verified FM output or a verified scenario text lookup. |

The existing CDS stays a `define view entity`, with its existing key, filter and
associations, including joint invoice linkage by `ContractAccount`. Only
`ServiceProvider` is added to its SQL projection. A function module cannot be
called inside CDS SQL; no SQL placeholder columns pretend to implement it.

The supplied global interface `ZIF_BPEM_SCENARIO_RESOLVER` and class
`ZCL_BPEM_CONTRACT_ENRICHER` are an application-layer integration scaffold, not a
SADL virtual-element implementation. Their source is in the `abap` directory.
The class accepts selected CDS rows and returns an ABAP table containing all
their scalar fields plus the two scenario fields and `ScenarioResolutionStatus`.
Associations remain in the CDS; the ABAP table does not materialize navigation
targets.

Consumers must explicitly select authorized contract rows, construct the
enricher with a site-specific resolver, and call `enrich` with those rows and an
explicit `iv_key_date`. `iv_language` defaults to `sy-langu`; normal UI consumption
should retain that default. The return table exposes all three requested names;
it is **not** a new CDS entity or an automatically published OData service.
Direct SQL, CDS preview, and existing SADL/OData consumption of the interface
view will not receive scenario enrichment. A consuming application/service must
serialize the returned fields (including their exact external casing), preserve
keys, and declare suitable service types/lengths after verifying the SAP types.
Filtering, sorting, or paging by scenario requires enrichment before those
operations; SQL cannot perform these operations on the added ABAP fields.
Existing contract-only paging enriches only the selected page.

No new authorization policy is introduced. The CDS retains its existing
`#NOT_REQUIRED` setting; the caller must enforce appropriate contract, PoD and
scenario access. The eventual resolver must use only authorized, read-only
lookups; it must not change SAP business data or commit work. Availability and
release status of the FM and lookup APIs must be checked for the target system,
especially for ABAP Cloud/restricted-language environments.

### Required resolver contract and unresolved SAP interfaces

The following are **design requirements**, not claims about the unverified SAP
FM interface. Before writing a concrete resolver, obtain SE37/ADT interface and
documentation exports and SE11/ADT type definitions from the target SAP release:

1. For `ISU_O_SCENARIO_AT_POD_GET`: exact parameter names and directions,
   mandatory/optional/default parameters, PoD identifier type (internal versus
   external), key-date/interval semantics, return/table types and components,
   scenario identifier type, cardinality, classic exceptions, return messages,
   and any required object lifecycle/cleanup calls.
2. For installation-to-PoD resolution: the supported API or actual DDIC
   relationship, installation and PoD identifier types, every intermediate
   relationship, validity start/end components, inclusive/exclusive boundaries,
   and any deletion/status rules. No lookup table or column names have been
   assumed here. Verify this path before coding it.
3. For descriptions: establish whether FM output really contains a
   language-specific description. Otherwise obtain the actual scenario text
   API/table/view, scenario key and language components, text component/type,
   validity and uniqueness rules, and language-key representation. Never derive
   a description from the scenario code or silently substitute another language.

No authoritative interface export or verified public interface reference is
available for these details in this change. A public SAP documentation fetch was
unsuccessful. Accordingly, no concrete `CALL FUNCTION` parameters, SAP return
components, lookup tables, or text columns are fabricated in the sources.

Research references (not a substitute for target-system verification):

* A [pinned third-party ABAP call site, `FORM hole_scenario`](https://github.com/abapGitAdmin/ZALL-E10/blob/6135b0e8266f742c233115225538602310ef9a55/src/%23adesso%23isu_tools/%23adesso%23dsc_sperrcockpit/%23adesso%23edisc/%23adesso%23ea_bor_methoden.fugr.%23adesso%23lea_bor_methodenf01.abap)
  corroborates usage of the requested FM with a structured scenario result.
  Its description output is commented out. It does not establish the formal
  interface, language behavior, or compatibility with the target release.
* Official SAP reference leads: [Point of Delivery](https://help.sap.com/docs/SAP_S4HANA_ON-PREMISE/905da66b76d1449fbe6ac26484842994/c260ce53118d4308e10000000a174cb4.html)
  and [Using Virtual Elements in CDS Projection Views](https://help.sap.com/docs/abap-cloud/abap-rap/using-virtual-elements-in-cds-projection-views?source=redirect&locale=en-US).
  Direct retrieval failed; these links are investigation leads, not verified
  evidence of an FM signature or a specific validity/lookup rule.

Once verified, implement `ZIF_BPEM_SCENARIO_RESOLVER~resolve` as follows:

* Use the supplied installation and the **same explicit key date** for the PoD,
  scenario, and any date-dependent text lookup. Do not silently use today's date,
  contract move-in/out dates, or the formatted date fields in the CDS. The caller
  chooses a business date; if different rows require different dates, invoke the
  enricher separately for each date.
* Select only relationships valid at that date under the verified SAP boundary
  rules. Zero valid PoDs yields `N`; more than one distinct eligible PoD yields
  `A`, not an arbitrary first row. Deduplicate identical relationship candidates
  before counting, using their verified business keys.
* Call the requested FM for the unique PoD and date using its actual interface.
  Apply its verified validity/cardinality rules: no scenario yields `N`;
  multiple distinct eligible scenarios yield `A`. Resolve the description for
  the unique scenario in `iv_language`. An absent translation leaves only the
  description initial, with status `F`; a failed text lookup is an error (`E`).
* Return `F` only with a noninitial scenario. Use `N` for absent data, `A` for
  ambiguity, and `E` for unsuccessful FM/API calls or invalid inputs. Translate
  documented FM exceptions and error returns into `E` or a checked exception
  derived from `CX_STATIC_CHECK`. Log diagnostic details through the consuming
  application's approved mechanism without exposing sensitive data.
* Clear work areas before each lookup/call and normalize returned identifiers
  using verified types/conversion rules. If caching across different
  installations that share a PoD, key FM results by PoD, date and language;
  never keep an unscoped cross-user cache.

The supplied enricher caches **all outcomes**, including errors, once per
installation within one invocation. Date and language are constant for that
invocation; subsequent invocations start with an empty cache. It retains input
order, duplicates, keys and row count. Missing installation gives `N`; an
initial date/language or unbound resolver gives `E`. Checked exceptions become
`E`. Unknown statuses or `F` without a scenario also become `E`. Both scenario
fields are cleared for every non-`F` result, preventing previous-row or erroneous
adapter values from leaking. Unexpected programming/runtime errors are not
silently swallowed. A failed result is retried only in a new invocation.

### Activation and validation

1. Verify the SAP release and the interfaces/types above. Existing prerequisites
   include `I_UtilitiesContract`, `zi_bpem_contract_ac_data`,
   `I_UtilsAccountDetnCodeText`, `I_UtilsBillgBlockReasonT`, and
   `ZI_BPEM_CA_JOINT_INV_STATUS`; their source is not included in this repository.
2. Apply the CDS source to its existing DDLS object and activate it. Confirm the
   additive alias is accepted by the target release and existing consumers.
3. Create and activate the global resolver interface, then the global enrichment
   class from their ABAP sources. Syntax-check against the target release; local
   source review is not an ABAP activation test.
4. Implement and activate the verified site-specific FM resolver. **Scenario
   integration remains blocked until this dependency exists.** Do not substitute
   a resolver that always returns missing data in production.
5. Connect an authorized application/service to the enricher, explicitly define
   its output metadata, and run SAP syntax checks, ATC and the tests below before
   transport. Do not replace the interface view with a projection/virtual-element
   view just to make annotations compile.

There is no test/build/lint infrastructure or SAP compiler in this repository.
Local validation is limited to diff/whitespace and source-invariant review,
secret scanning and the available security checker. No SAP activation, ABAP Unit,
FM execution, DDIC compatibility, authorization or service behavior is claimed.
Add ABAP Unit tests with resolver doubles and integration tests in the target
SAP system covering:

| Case | Expected result |
| --- | --- |
| Valid installation, unique valid PoD/scenario | `F`, exact FM scenario and logon-language description; provider equals existing provider field. |
| Missing installation, PoD or scenario | `N`, both scenario fields initial, original row retained; no FM call without a unique PoD. |
| Multiple valid PoDs or scenarios | `A`, no arbitrary selection; identical duplicate candidates do not create false ambiguity. |
| Language | Correct logon-language text; missing translation leaves only description blank; lookup error gives `E`. |
| Key-date boundaries | Before/start/end/after each verified validity interval, open-ended validity and overlaps; every lookup uses the same date. |
| Repeated installations | One resolver invocation per distinct installation per call, including `N`/`A`/`E`; separate dates/languages/calls do not reuse cached results. |
| Errors and row isolation | FM exceptions/error returns, checked exceptions, unknown status, `F` without scenario, initial date/language and unbound resolver give `E`; success followed by missing/ambiguous/error never leaks values. |
| Compatibility | Empty input, duplicates and input order preserved; unchanged keys/row count, contract fields, associations and joint invoice linkage by `ContractAccount`; authorized service exposes exact field names. |
