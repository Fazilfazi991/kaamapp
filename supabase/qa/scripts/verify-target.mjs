import { assertQaSupabaseTarget } from "../../../scripts/assert-qa-supabase-target.mjs";
import { productionRef, qaRef, qaUrl } from "./bundle-config.mjs";

assertQaSupabaseTarget({ projectRef: qaRef, supabaseUrl: qaUrl });
console.log("TARGET PROJECT: Kaam QA");
console.log(`TARGET PROJECT REF: ${qaRef}`);
console.log(`PRODUCTION PROJECT REF: ${productionRef}`);
console.log("SAFE TO CONTINUE: YES");
