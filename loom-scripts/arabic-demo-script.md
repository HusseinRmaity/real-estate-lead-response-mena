# Demo script — Arabic demo (سكربت العرض بالعربي)

**Target length:** 2:30–3:30
**Audience:** أصحاب ومدراء مكاتب عقارية في الخليج والشام (دبي، الرياض، الدوحة، بيروت، عمّان).
**Goal:** إثبات — على هاتف حقيقي — أن العميل المحتمل يستلم رداً على واتساب خلال أقل من دقيقة، بلغته، ثم يُؤهَّل عبر محادثة طبيعية، ويصل إلى الـ CRM وسلاك كعميل مُقيَّم جاهز للاتصال.

**Recording notes (بالإنجليزي للتحضير):**
- Same setup checklist as the English script (tunnel + Twilio inbound + pruned data + windows arranged + phone in frame).
- Record during working hours (or use a Gulf number in Gulf daytime) so the ack fires immediately, not delayed by the send-window.
- Voiceover below is in Modern Standard Arabic with a warm, professional register — understood across Gulf and Levant. Keep it natural, not read-off-a-page. Stage directions stay in English.

---

## Shot list & voiceover (التعليق الصوتي)

### 0:00–0:20 — الافتتاحية (Hook)
*Show the lead form. The "under 60s" clock visible.*
> «العميل العقاري في الخليج أو الشام بينتظر رد على الواتساب خلال دقائق — مش إيميل، ولا مكالمة بكرة. لو فاتتك هاللحظة، بتخسر العميل. خليني أوريك نظام بيرد بأقل من دقيقة، بلغة العميل، وبأي وقت — وعلى هاتفي أنا شخصياً.»

### 0:20–0:45 — إرسال العميل (Submit)
> «هاي استمارة موقع عادية — بس بتشتغل بنفس الطريقة لو إجا العميل من "بروبرتي فايندر" أو "بيوت" أو إعلان على ميتا. رح أدخل كمشتري نقدي بيدوّر على شقة في دبي مارينا.»

*Fill the form: name, your WhatsApp number, "شراء" (Buy), "شقة غرفتين، دبي مارينا", short message. Click Send. Success state appears.*

### 0:45–1:05 — النظام يشتغل (n8n)
> «وراء هاي الضغطة، مسار الإدخال بيتأكد من البيانات، بيمنع التكرار، بيكتشف اللغة، بيقيّم نية العميل بنموذج ذكاء اصطناعي سريع، وبيخزّن كل شي — قبل ما يبعت أي رسالة.»

*Cut to n8n `01 - Lead Intake` execution lighting up green. Point at Validate → Dedupe → Language → Intent → Insert.*

### 1:05–1:35 — الهاتف بيرنّ (اللقطة الأهم)
> «وهلأ الجزء اللي بيقفل الصفقة — هاتفي.»

*Hold up the phone. The Arabic WhatsApp acknowledgment has arrived. Show the timestamp.*
> «أقل من دقيقة. رحّب فيّ، وذكر "دبي مارينا" بالتحديد، وسأل سؤال تأهيلي واحد — ما بيرمي استمارة على العميل، بيفتح محادثة.»

### 1:35–2:10 — محادثة التأهيل (Qualifying)
> «فبرد متل ما بيرد أي عميل حقيقي.»

*Reply on the phone in Arabic: budget + currency + timeline (e.g. «حوالي مليونين درهم، كاش، بدي أعاين هالأسبوع»). The bot replies again in Arabic.*
> «عم يستخرج الميزانية والتوقيت ونية الشراء ونحنا عم نحكي — وأبداً ما بيفترض العملة، وهاد مهم لأن "مليونين" ممكن تكون درهم أو ريال أو دولار. وبيوقف حاله عند ست رسائل، وبعدها بيحوّلني لموظف بشري.»

### 2:10–2:40 — التسليم إلى الـ CRM وسلاك
> «أول ما بيجمع معلومات كافية، بيتقيّم العميل وبينتقل للموظف.»

*Cut to Slack `#leads`: the rich card — score, tier, budget, area, summary, next action, HubSpot links. Then HubSpot: contact + deal with qualification fields.*
> «الموظف بيفتح سلاك على عميل مُقيَّم — "هوت"، مليونين درهم، بدو يعاين هالأسبوع — ومعه جهة اتصال وصفقة جاهزة بالـ HubSpot. بدون أي إدخال بيانات. بس بيتصل.»

### 2:40–3:15 — ليش هالنظام مختلف + العائد
> «هالنظام مبني لهالسوق، مش مضاف عليه. عربي، إنجليزي، وفرنسي. عطل نهاية الأسبوع بيفرق بين الخليج والشام. وبيراعي أوقات الصلاة بالإرسال. ومبني بمعايير إنتاج كاملة — إعادة محاولة، معالج أخطاء مركزي، وتقرير يومي — فبيشتغل لحاله بدون مراقبة.»
>
> «لفريق بدبي بيستقبل ٥٠٠ عميل بالشهر، استرجاع كم عميل كانوا بيضيعوا بسبب بطء الرد - الرد السريع بيغطّي كلفة النظام أضعاف. الأرقام التفصيلية موجودة بدراسة الحالة.»

### 3:15–3:30 — الدعوة للتواصل (CTA)
> «إذا عندك مكتب عقاري بالخليج أو الشام وعم تخسر عملاء بسبب بطء الرد على واتساب، أنا ببنيلك هالنظام على أدواتك — الـ CRM تبعك، رقمك، ولغتك. الرابط بالوصف. خلينا نحكي.»

---

## Notes (ملاحظات)
- The phone reveal is the emotional peak — keep it in frame, don't cut away.
- Keep the register warm and professional; avoid «إن شاء الله» for any timing/logistics (use «سنبذل قصارى جهدنا» / «رح نتصرف بأسرع وقت»). Avoid religious phrasing that assumes the viewer's faith.
- One sentence per stage. Let the phone and Slack do the selling.
- Same take can be re-shot if Twilio is rate-limited; the phone reveal must be real.
- Don't put invented numbers on screen — the ROI is an illustrative model (see the case study).
