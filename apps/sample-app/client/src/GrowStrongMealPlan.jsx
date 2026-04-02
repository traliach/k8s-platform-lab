import { useState } from "react";

const days = [
  {
    name: "MON",
    oil: { emoji: "🌴", label: "Palm Oil Day", desc: "Huile de palme · Vitamin A & E · 5–8g (1–1½ tsp) per meal", bg: "#4E342E", bg2: "#8B3A0F" },
    meals: [
      { type: "breakfast", ico: "🌅", lbl: "Breakfast · 7–8am", name: "Oatmeal with banana and peanut butter",
        desc: "Cook rolled oats in full fat milk (not water). Mash in a ripe banana and stir in peanut butter until smooth. Add moringa powder — it disappears completely. A classic combination that genuinely works.",
        meas: [["Rolled oats","30g (4 tbsp)"],["Full fat milk","160ml"],["Ripe banana","60g (½ small)"],["Peanut butter","15g (1 tbsp)"],["Moringa powder","2g (½ tsp)"],["Butter (finish)","5g (1 tsp)"]], kcal: "~340 kcal" },
      { type: "snack", ico: "🥑", lbl: "Snack · 10am", name: "Avocado on soft bread",
        desc: "Mash ripe avocado with a tiny pinch of salt and a drop of lemon juice. Spread generously on soft white bread or brioche. No complicated preparation needed.",
        meas: [["Avocado","60g (4 tbsp mashed)"],["Soft white bread","30g (1 slice)"],["Salt","pinch"],["Lemon juice","2–3 drops"]], kcal: "~195 kcal" },
      { type: "lunch", ico: "🍝", lbl: "Lunch · 12–1pm", name: "Sardine pasta with butter",
        desc: "Cook small pasta (ditalini or pastina) until very soft. Drain sardines from the can, mash very finely with a fork, and toss through the warm pasta with butter. A classic Italian combination. Add a tiny pinch of salt.",
        meas: [["Small pasta (cooked)","100g"],["Canned sardines (drained)","40g (1 small can)"],["Butter","8g (1½ tsp)"],["Salt","tiny pinch"]], kcal: "~310 kcal" },
      { type: "snack", ico: "🍌", lbl: "Snack · 3–4pm", name: "Full fat yogurt with mashed banana",
        desc: "Stir mashed ripe banana into full fat plain yogurt. Naturally sweet — no added sugar needed. Probiotics in yogurt help nutrient absorption.",
        meas: [["Full fat plain yogurt","80g (4 tbsp)"],["Ripe banana","60g (½ small)"]], kcal: "~145 kcal" },
      { type: "dinner", ico: "🌙", lbl: "Dinner · 6–7pm", name: "Black bean stew with ground chicken and rice",
        desc: "Cook soft black beans with finely ground chicken in a simple broth (onion, a little tomato, salt). Blend or mash the stew smooth. Serve over soft white rice. Beans + chicken is a complete protein.",
        meas: [["Cooked black beans","60g (4 tbsp)"],["Ground chicken (cooked)","30g (2 tbsp)"],["Soft white rice","90g"],["Olive oil in stew","5g (1 tsp)"],["Salt","pinch"]], kcal: "~295 kcal" },
    ]
  },
  {
    name: "TUE",
    oil: { emoji: "🫒", label: "Olive Oil Day", desc: "Huile d'olive · Heart-healthy · Neutral taste · 5–8g per meal", bg: "#1B5E20", bg2: "#33691E" },
    meals: [
      { type: "breakfast", ico: "🌅", lbl: "Breakfast · 7–8am", name: "Scrambled eggs with butter and toast",
        desc: "Scrambled eggs cooked slowly in butter until soft and creamy — not dry. Serve on buttered soft toast. Add a cup of warm full fat milk on the side. The most classic breakfast that works for toddlers.",
        meas: [["Eggs","100g (2 eggs)"],["Butter for cooking","7g (1½ tsp)"],["Soft toast","30g (1 slice)"],["Butter for toast","5g (1 tsp)"],["Full fat milk (cup)","120ml"]], kcal: "~360 kcal" },
      { type: "snack", ico: "🍌", lbl: "Snack · 10am", name: "Banana slices with peanut butter",
        desc: "Slice a ripe banana and dip into peanut butter, or mash together. Simple, familiar, and toddlers almost always accept this combination.",
        meas: [["Ripe banana","80g (1 small)"],["Peanut butter","12g (¾ tbsp)"]], kcal: "~165 kcal" },
      { type: "lunch", ico: "🥘", lbl: "Lunch · 12–1pm", name: "Shepherd's pie — mashed potato with ground beef",
        desc: "Cook ground beef with onion, a little carrot (mashed very fine), and a small amount of tomato puree. Top with creamy mashed potato made with full fat milk and butter. A universal comfort food.",
        meas: [["Ground beef (cooked)","40g"],["Mashed potato","120g"],["Butter in potato","8g (1½ tsp)"],["Full fat milk in potato","40ml"],["Ground carrot in meat","20g"],["Tomato puree","10g (2 tsp)"]], kcal: "~330 kcal" },
      { type: "snack", ico: "🍼", lbl: "Snack · 3–4pm", name: "Cerelac with full fat milk",
        desc: "Cerelac prepared with warm full fat milk. Keep this as a reliable, familiar afternoon snack. Do not add oil to Cerelac — it is already well balanced.",
        meas: [["Cerelac powder","25g (4 tbsp)"],["Full fat milk (warm)","130ml"]], kcal: "~165 kcal" },
      { type: "dinner", ico: "🌙", lbl: "Dinner · 6–7pm", name: "Okra stew with dried fish and white rice",
        desc: "Cook okra until very soft, add finely ground dried fish (soaked first to remove excess salt), season lightly, finish with olive oil. Serve over soft white rice. Okra + dried fish is a proven West African combination.",
        meas: [["Okra (cooked soft)","60g"],["Dried fish (soaked, ground)","20g"],["Soft white rice","90g"],["Olive oil","6g (1 tsp)"],["Salt","tiny pinch"]], kcal: "~255 kcal" },
    ]
  },
  {
    name: "WED",
    oil: { emoji: "🫒", label: "Olive Oil Day", desc: "Huile d'olive · Also butter for pancakes · 5–8g per meal", bg: "#1B5E20", bg2: "#33691E" },
    meals: [
      { type: "breakfast", ico: "🌅", lbl: "Breakfast · 7–8am", name: "Mini pancakes with butter and mashed banana",
        desc: "Make small soft pancakes with egg, full fat milk, and flour. Cook in butter. Serve topped with mashed ripe banana. No syrup needed — the banana is naturally sweet.",
        meas: [["Plain flour","40g (4 tbsp)"],["Egg","50g (1 egg)"],["Full fat milk","80ml"],["Butter for cooking","6g (1 tsp)"],["Ripe banana (topping)","70g"]], kcal: "~310 kcal" },
      { type: "snack", ico: "🥚", lbl: "Snack · 10am", name: "Soft boiled egg and avocado mash",
        desc: "Soft boil one egg, remove the yolk and mash with avocado. Egg yolk + avocado is an excellent fat combination.",
        meas: [["Egg yolk","17g (1 yolk)"],["Avocado","50g (3 tbsp)"],["Salt","pinch"]], kcal: "~160 kcal" },
      { type: "lunch", ico: "🥣", lbl: "Lunch · 12–1pm", name: "Red lentil soup with soft bread and olive oil",
        desc: "Simmer red lentils with onion, a little carrot, and a pinch of cumin until completely soft. Blend smooth. Finish with a drizzle of olive oil. Serve with soft bread for dipping.",
        meas: [["Red lentils (cooked)","80g"],["Onion (soft cooked)","20g"],["Carrot (soft cooked)","20g"],["Olive oil","7g (1½ tsp)"],["Soft bread","30g (1 slice)"],["Salt and cumin","pinch each"]], kcal: "~290 kcal" },
      { type: "snack", ico: "🍓", lbl: "Snack · 3–4pm", name: "Full fat yogurt with mashed berries",
        desc: "Mash a few soft strawberries or blueberries into full fat plain yogurt. The fruit adds Vitamin C.",
        meas: [["Full fat plain yogurt","90g"],["Soft berries (mashed)","40g"]], kcal: "~120 kcal" },
      { type: "dinner", ico: "🌙", lbl: "Dinner · 6–7pm", name: "Ground chicken rice bowl with soft carrots and butter",
        desc: "Stir-fry finely ground chicken in olive oil until fully cooked. Serve over soft white rice with steamed carrots mashed into the dish. Finish with a small pat of butter.",
        meas: [["Ground chicken (cooked)","40g"],["Soft white rice","90g"],["Carrots (steamed, mashed)","40g"],["Olive oil","5g (1 tsp)"],["Butter (finish)","5g (1 tsp)"]], kcal: "~285 kcal" },
    ]
  },
  {
    name: "THU",
    oil: { emoji: "🧈", label: "Butter Day", desc: "Beurre · French toast · Sweet potato · Vitamins A, D, K · 5–7g per meal", bg: "#4E342E", bg2: "#6D3B00" },
    meals: [
      { type: "breakfast", ico: "🌅", lbl: "Breakfast · 7–8am", name: "French toast with full fat milk",
        desc: "Dip soft bread in a mixture of egg, full fat milk, and a tiny pinch of cinnamon. Cook in butter until golden and soft.",
        meas: [["Soft white bread","60g (2 slices)"],["Egg","50g (1 egg)"],["Full fat milk","50ml"],["Butter for cooking","7g (1½ tsp)"],["Ripe banana (side)","60g"],["Cinnamon","tiny pinch"]], kcal: "~355 kcal" },
      { type: "snack", ico: "🐟", lbl: "Snack · 10am", name: "Sardines mashed with avocado on soft crackers",
        desc: "Drain canned sardines and mash very finely. Mix with mashed avocado and a drop of lemon. Spread on soft crackers.",
        meas: [["Canned sardines (drained)","30g"],["Avocado","40g (2–3 tbsp)"],["Soft crackers","20g (3–4 crackers)"],["Lemon juice","2–3 drops"]], kcal: "~195 kcal" },
      { type: "lunch", ico: "🥣", lbl: "Lunch · 12–1pm", name: "Bean and dried fish stew with soft bread",
        desc: "Simmer white beans with soaked finely ground dried fish, onion, tomato, and a little olive oil until very soft and soupy. Serve with soft bread for dipping.",
        meas: [["White beans (cooked)","70g"],["Dried fish (soaked, ground)","20g"],["Tomato (soft cooked)","30g"],["Olive oil","6g (1 tsp)"],["Soft bread","30g (1 slice)"],["Salt","tiny pinch"]], kcal: "~270 kcal" },
      { type: "snack", ico: "🍌", lbl: "Snack · 3–4pm", name: "Banana and yogurt",
        desc: "Mash banana into full fat yogurt. A reliable snack the child already knows.",
        meas: [["Ripe banana","70g"],["Full fat yogurt","70g"],["Baobab flour (optional)","3g (1 tsp)"]], kcal: "~150 kcal" },
      { type: "dinner", ico: "🌙", lbl: "Dinner · 6–7pm", name: "Baked sweet potato with flaked fish and peas",
        desc: "Bake or boil a sweet potato until very soft. Mash with butter. Flake canned sardines or cooked tilapia very finely and mix in. Serve with soft steamed peas.",
        meas: [["Sweet potato (baked, mashed)","130g"],["Flaked sardines or tilapia","35g"],["Butter","7g (1½ tsp)"],["Soft peas (mashed)","40g"]], kcal: "~295 kcal" },
    ]
  },
  {
    name: "FRI",
    oil: { emoji: "🧈", label: "Butter Day", desc: "Beurre · Burger + scrambled eggs · Vitamins A, D, K · 5–7g per meal", bg: "#4E342E", bg2: "#6D3B00" },
    meals: [
      { type: "breakfast", ico: "🌅", lbl: "Breakfast · 7–8am", name: "Bouillie de mil with peanut paste and moringa",
        desc: "Millet porridge made with full fat milk. Add peanut paste and moringa powder. Stir smooth.",
        meas: [["Millet flour","30g (3 tbsp)"],["Full fat milk","160ml"],["Peanut paste","15g (1 tbsp)"],["Butter","5g (1 tsp)"],["Moringa powder","2g (½ tsp)"]], kcal: "~340 kcal" },
      { type: "snack", ico: "🧀", lbl: "Snack · 10am", name: "Soft cheese with crackers",
        desc: "Soft full-fat cheese (cream cheese, brie, or processed cheese slice) with soft crackers.",
        meas: [["Soft/cream cheese","30g (2 tbsp)"],["Soft crackers","25g (4 crackers)"]], kcal: "~165 kcal" },
      { type: "lunch", ico: "🍔", lbl: "Lunch · 12–1pm", name: "Mini soft burger with avocado and melted cheese",
        desc: "Cook a small ground beef patty well done and soft. Place on a soft small bun with melted cheese and mashed avocado. Cut into small pieces.",
        meas: [["Ground beef patty (cooked)","50g"],["Soft small bun","40g"],["Cheese slice (melted)","20g"],["Avocado (mashed)","40g"],["Salt","tiny pinch"]], kcal: "~380 kcal" },
      { type: "snack", ico: "🍋", lbl: "Snack · 3–4pm", name: "Mashed mango or ripe banana",
        desc: "Mash soft ripe mango or banana. Mango is high in Vitamin A and C.",
        meas: [["Ripe mango or banana","100g"],["Full fat yogurt (optional)","40g"]], kcal: "~115 kcal" },
      { type: "dinner", ico: "🌙", lbl: "Dinner · 6–7pm", name: "Sardine and potato mash with soft peas",
        desc: "Mash boiled potato with butter and full fat milk until very smooth. Mix in finely mashed sardines. Serve with soft mashed peas on the side.",
        meas: [["Potato (boiled, mashed)","130g"],["Canned sardines (mashed fine)","40g"],["Butter","8g (1½ tsp)"],["Full fat milk in mash","40ml"],["Soft peas (mashed)","40g"]], kcal: "~310 kcal" },
    ]
  },
  {
    name: "SAT",
    oil: { emoji: "🫒", label: "Olive Oil Day", desc: "Huile d'olive · Pizza + pasta + eggs · 5–8g per meal", bg: "#1B5E20", bg2: "#33691E" },
    meals: [
      { type: "breakfast", ico: "🌅", lbl: "Breakfast · 7–8am", name: "Egg and avocado on soft toast",
        desc: "Scrambled egg cooked in butter on soft toast, topped with mashed avocado. Add moringa powder into the egg as it cooks — invisible.",
        meas: [["Eggs","100g (2 eggs)"],["Butter","6g (1 tsp)"],["Soft toast","35g (1 thick slice)"],["Avocado (mashed on top)","50g"],["Moringa powder","2g (½ tsp)"]], kcal: "~370 kcal" },
      { type: "snack", ico: "🥣", lbl: "Snack · 10am", name: "Oatmeal with full fat milk and banana",
        desc: "A lighter mid-morning oatmeal with full fat milk and mashed banana.",
        meas: [["Rolled oats","25g (3 tbsp)"],["Full fat milk","140ml"],["Ripe banana","60g"],["Baobab flour","3g (1 tsp)"]], kcal: "~215 kcal" },
      { type: "lunch", ico: "🍕", lbl: "Lunch · 12–1pm", name: "Mini soft pizza with ground meat and cheese",
        desc: "Use a soft flatbread or pita as the base. Spread tomato sauce, sprinkle grated mozzarella, top with finely ground cooked beef or chicken. Bake at low heat until cheese melts.",
        meas: [["Soft pita or flatbread","50g"],["Tomato sauce","30g (2 tbsp)"],["Grated mozzarella","30g"],["Ground meat (cooked)","30g"],["Olive oil (drizzle)","4g (¾ tsp)"]], kcal: "~315 kcal" },
      { type: "snack", ico: "🍓", lbl: "Snack · 3–4pm", name: "Full fat yogurt with mashed strawberries",
        desc: "Mash soft strawberries or blueberries into full fat yogurt.",
        meas: [["Full fat plain yogurt","90g"],["Soft strawberries (mashed)","50g"]], kcal: "~115 kcal" },
      { type: "dinner", ico: "🌙", lbl: "Dinner · 6–7pm", name: "Sardine pasta with olive oil and soft vegetables",
        desc: "Small soft pasta with mashed sardines, a drizzle of olive oil, and finely pureed cooked zucchini or spinach mixed in.",
        meas: [["Small pasta (cooked)","100g"],["Sardines (mashed fine)","35g"],["Olive oil","7g (1½ tsp)"],["Zucchini (pureed, cooked)","40g"],["Salt","tiny pinch"]], kcal: "~295 kcal" },
    ]
  },
  {
    name: "SUN",
    oil: { emoji: "🌴", label: "Palm Oil Day", desc: "Huile de palme · For Sunday stew · Vitamin A rich · 5–8g in sauce only", bg: "#BF360C", bg2: "#8B3A0F" },
    meals: [
      { type: "breakfast", ico: "🌅", lbl: "Breakfast · 7–8am", name: "Pancakes with butter and mashed mango",
        desc: "Soft pancakes made with full fat milk and egg, cooked in butter. Top with mashed ripe mango instead of syrup.",
        meas: [["Plain flour","40g (4 tbsp)"],["Egg","50g (1 egg)"],["Full fat milk","80ml"],["Butter for cooking","6g (1 tsp)"],["Ripe mango (mashed topping)","80g"]], kcal: "~305 kcal" },
      { type: "snack", ico: "🥑", lbl: "Snack · 10am", name: "Avocado mash with moringa and full fat milk",
        desc: "Mash avocado with a pinch of salt. Add moringa powder and stir in. Serve with a small cup of full fat milk on the side.",
        meas: [["Avocado","60g (4 tbsp)"],["Moringa powder","2g (½ tsp)"],["Salt","pinch"],["Full fat milk (cup)","120ml"]], kcal: "~215 kcal" },
      { type: "lunch", ico: "🥘", lbl: "Lunch · 12–1pm", name: "Slow-cooked chicken and vegetable stew",
        desc: "Slow cook chicken thighs with soft vegetables (carrot, potato, peas, onion) until everything is very tender. Blend or finely shred the chicken.",
        meas: [["Chicken (cooked, ground)","45g"],["Potato (soft)","80g"],["Carrot (soft, mashed)","40g"],["Palm oil in stew","7g (1½ tsp)"],["Soft peas","30g"],["Broth/water","enough to cover"]], kcal: "~285 kcal" },
      { type: "snack", ico: "🍼", lbl: "Snack · 3–4pm", name: "Cerelac with full fat milk",
        desc: "Cerelac with warm full fat milk. A familiar Sunday afternoon snack.",
        meas: [["Cerelac powder","25g (4 tbsp)"],["Full fat milk (warm)","130ml"],["Baobab flour","3g (1 tsp)"]], kcal: "~175 kcal" },
      { type: "dinner", ico: "🌙", lbl: "Dinner · 6–7pm", name: "Bean and sardine rice",
        desc: "Cook white rice until very soft. Mix in white beans and finely mashed sardines with a drizzle of olive oil.",
        meas: [["Soft white rice","90g"],["White beans (cooked)","50g"],["Sardines (mashed fine)","30g"],["Olive oil","6g (1 tsp)"],["Salt","tiny pinch"]], kcal: "~275 kcal" },
    ]
  }
];

const mealBg = { breakfast: "#FFF8E1", snack: "#F1F8E9", lunch: "#FBE9E7", dinner: "#EDE7F6" };

export default function GrowStrongMealPlan() {
  const [activeDay, setActiveDay] = useState(0);
  const [openMeal, setOpenMeal] = useState(null);
  const day = days[activeDay];

  return (
    <div style={{ fontFamily: "system-ui, sans-serif", background: "#FDF6E9", minHeight: "100vh", maxWidth: 500, margin: "0 auto" }}>
      <div style={{ background: "linear-gradient(135deg, #5D4037, #8D6E63)", padding: "22px 18px 16px", position: "relative", overflow: "hidden" }}>
        <div style={{ position: "absolute", top: -30, right: -30, width: 150, height: 150, borderRadius: "50%", background: "rgba(244,162,97,0.15)" }} />
        <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: 2, textTransform: "uppercase", background: "#F4A261", color: "#3E1F0A", display: "inline-block", padding: "3px 10px", borderRadius: 20, marginBottom: 8 }}>
          Weekly Meal Plan · v3
        </div>
        <div style={{ fontSize: 24, fontWeight: 700, color: "#FFF8F0", lineHeight: 1.2, position: "relative", zIndex: 1 }}>
          Grow <span style={{ color: "#F4A261" }}>Strong</span><br />Little One
        </div>
        <div style={{ fontSize: 11.5, color: "rgba(255,248,240,0.72)", marginTop: 7, lineHeight: 1.55, position: "relative", zIndex: 1 }}>
          Mixed cuisines · US pantry + West African staples<br />
          All fish & meat ground fine · Oil rotates daily · Measured in grams
        </div>
      </div>

      <div style={{ background: "#795548", padding: "8px 14px", display: "flex", gap: 14, overflowX: "auto", scrollbarWidth: "none" }}>
        {["Peanut butter daily", "Avocado = best fat", "Moringa once/day", "Baobab 3×/week", "Full fat milk always", "5 meals every 2–3h"].map(t => (
          <span key={t} style={{ whiteSpace: "nowrap", fontSize: 11, color: "#FFF8F0", fontWeight: 600, flexShrink: 0 }}>{t}</span>
        ))}
      </div>

      <div style={{ display: "flex", gap: 4, padding: "10px 12px 0", background: "#FFF8EE", borderBottom: "1px solid #F5E6C8", overflowX: "auto", scrollbarWidth: "none", position: "sticky", top: 0, zIndex: 50 }}>
        {days.map((d, i) => (
          <button key={d.name} onClick={() => { setActiveDay(i); setOpenMeal(null); }} style={{
            flexShrink: 0, padding: "6px 12px", borderRadius: "8px 8px 0 0", border: "none",
            background: activeDay === i ? "#795548" : "transparent",
            color: activeDay === i ? "#FFF8F0" : "#999",
            fontSize: 11, fontWeight: 700, cursor: "pointer"
          }}>{d.name}</button>
        ))}
      </div>

      <div style={{ background: `linear-gradient(135deg, ${day.oil.bg2}, ${day.oil.bg})`, padding: "11px 16px", display: "flex", alignItems: "center", gap: 10 }}>
        <span style={{ fontSize: 24 }}>{day.oil.emoji}</span>
        <div>
          <div style={{ color: "#FFF8F0", fontWeight: 700, fontSize: 13 }}>{day.oil.label}</div>
          <div style={{ color: "rgba(255,248,240,0.80)", fontSize: 11, marginTop: 1 }}>{day.oil.desc}</div>
        </div>
      </div>

      <div style={{ background: "#F4A261", margin: "10px 12px 4px", borderRadius: 8, padding: "8px 12px", fontSize: 12, fontWeight: 700, color: "#3E1F0A" }}>
        Target: 1100–1300 kcal · 5 meals every 2–3 hours
      </div>

      <div style={{ padding: "6px 12px 14px" }}>
        {day.meals.map((meal, i) => {
          const isOpen = openMeal === i;
          return (
            <div key={i} style={{ background: "white", borderRadius: 12, marginBottom: 9, overflow: "hidden", boxShadow: "0 1px 6px rgba(93,64,55,0.09)", border: "0.5px solid #EDE0D4" }}>
              <div onClick={() => setOpenMeal(isOpen ? null : i)} style={{ display: "flex", alignItems: "center", gap: 9, padding: "10px 13px", cursor: "pointer" }}>
                <div style={{ width: 34, height: 34, borderRadius: "50%", background: mealBg[meal.type] || "#F5F5F5", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 17, flexShrink: 0 }}>{meal.ico}</div>
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: 9, fontWeight: 700, letterSpacing: 1.5, textTransform: "uppercase", color: "#bbb" }}>{meal.lbl}</div>
                  <div style={{ fontSize: 14, fontWeight: 700, color: "#2C1A0E", lineHeight: 1.2 }}>{meal.name}</div>
                </div>
                <div style={{ display: "flex", alignItems: "center", gap: 5, flexShrink: 0 }}>
                  <span style={{ fontSize: 11, fontWeight: 700, color: "#F4A261" }}>{meal.kcal}</span>
                  <span style={{ color: "#ccc", fontSize: 12 }}>{isOpen ? "▲" : "▼"}</span>
                </div>
              </div>
              {isOpen && (
                <div style={{ padding: "11px 13px", borderTop: "0.5px solid #F5EDE5" }}>
                  <p style={{ fontSize: 12.5, lineHeight: 1.65, color: "#555", marginBottom: 11 }}>{meal.desc}</p>
                  <div style={{ background: "#F5EDE5", borderRadius: 8, padding: "9px 11px", marginBottom: 9 }}>
                    <div style={{ fontSize: 9, fontWeight: 700, letterSpacing: 1.5, textTransform: "uppercase", color: "#8D6E63", marginBottom: 6 }}>Measurements</div>
                    {meal.meas.map(([name, val], j) => (
                      <div key={j} style={{ display: "flex", justifyContent: "space-between", padding: "3.5px 0", borderBottom: j < meal.meas.length - 1 ? "0.5px solid rgba(141,110,99,0.15)" : "none", fontSize: 12 }}>
                        <span style={{ color: "#666" }}>{name}</span>
                        <span style={{ fontWeight: 700, color: "#5D4037" }}>{val}</span>
                      </div>
                    ))}
                  </div>
                  <div style={{ background: "#FFF3E0", borderRadius: 7, padding: "6px 11px", fontSize: 11.5, color: "#6D4C41", fontWeight: 600, borderLeft: "3px solid #F4A261" }}>
                    🔥 {meal.kcal} · full fat, calorie-dense
                  </div>
                </div>
              )}
            </div>
          );
        })}
      </div>

      <div style={{ margin: "0 12px 10px", background: "#4A7C59", borderRadius: 11, padding: "13px 15px", color: "white", fontSize: 12.5, lineHeight: 1.6 }}>
        <strong style={{ display: "block", fontSize: 13, marginBottom: 4 }}>🌿 Moringa (Kelen-kelen / Zogale)</strong>
        Add <strong>2g (½ tsp)</strong> once per day — in the morning meal where it's invisible.
      </div>
      <div style={{ margin: "0 12px 10px", background: "#8B5E3C", borderRadius: 11, padding: "13px 15px", color: "white", fontSize: 12.5, lineHeight: 1.6 }}>
        <strong style={{ display: "block", fontSize: 13, marginBottom: 4 }}>🌳 Baobab Flour (Pain de Singe)</strong>
        Use <strong>3g (1 tsp)</strong> three times a week in a porridge or smoothie.
      </div>

      <div style={{ background: "#5D4037", padding: "18px 18px 28px" }}>
        <div style={{ fontSize: 16, fontWeight: 700, color: "#FFF8F0", marginBottom: 14 }}>Rules that matter most</div>
        {[
          ["1", "Always grind meat and fish completely fine before mixing into any dish."],
          ["2", "Never dilute Cerelac or milk with water. Full fat milk only, every single time."],
          ["3", "Add fat to everything. Butter in eggs, olive oil in pasta, peanut butter in oatmeal."],
          ["4", "5 small meals, not 3 big ones. Feed every 2–3 hours with small calorie-dense portions."],
          ["5", "Weigh every 2 weeks. No gain after 3–4 weeks? Visit a pediatrician."],
        ].map(([n, text]) => (
          <div key={n} style={{ display: "flex", gap: 9, marginBottom: 11 }}>
            <div style={{ background: "#F4A261", color: "#3E1F0A", borderRadius: "50%", width: 24, height: 24, display: "flex", alignItems: "center", justifyContent: "center", fontSize: 11, fontWeight: 700, flexShrink: 0, marginTop: 1 }}>{n}</div>
            <p style={{ fontSize: 12.5, color: "rgba(255,248,240,0.85)", lineHeight: 1.55, margin: 0 }}>{text}</p>
          </div>
        ))}
      </div>
    </div>
  );
}
