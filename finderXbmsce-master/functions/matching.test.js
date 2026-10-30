const test = require("node:test");
const assert = require("node:assert/strict");
const {
  rankTeammates,
  scoreCandidate,
  skillCategory,
} = require("./matching");

test("maps skills to the supported matching categories", () => {
  assert.equal(skillCategory("React"), "frontend");
  assert.equal(skillCategory("Node.js APIs"), "backend");
  assert.equal(skillCategory("Flutter"), "mobile");
  assert.equal(skillCategory("Machine Learning"), "data/AI");
  assert.equal(skillCategory("Figma UI/UX"), "design");
  assert.equal(skillCategory("Arduino"), "hardware");
  assert.equal(skillCategory("Poetry"), null);
});

test("rewards required skills in a complementary category", () => {
  const user = ["Flutter", "Dart"];
  const complement = scoreCandidate(user, ["TensorFlow", "Python"], [
    "TensorFlow",
  ]);
  const duplicate = scoreCandidate(user, ["Flutter", "Dart"], ["Flutter"]);

  assert.ok(complement.score > duplicate.score);
  assert.match(complement.reason, /TensorFlow/);
});

test("rewards covering a required category with a different skill", () => {
  const categoryMatch = scoreCandidate(
      ["Flutter"],
      ["Pandas"],
      ["Data analysis"],
  );
  const unrelated = scoreCandidate(
      ["Flutter"],
      ["Figma"],
      ["Data analysis"],
  );

  assert.ok(categoryMatch.score > unrelated.score);
  assert.match(categoryMatch.reason, /data\/AI/);
});

test("penalizes identical skill sets", () => {
  const identical = scoreCandidate(
      ["React", "TypeScript"],
      ["TypeScript", "React"],
  );
  const complementary = scoreCandidate(
      ["React", "TypeScript"],
      ["Arduino", "Embedded"],
  );

  assert.ok(identical.score < complementary.score);
  assert.match(identical.reason, /similar/);
});

test("returns only the top ten candidates by score", () => {
  const candidates = Array.from({length: 14}, (_, index) => ({
    uid: `candidate-${index}`,
    name: `Candidate ${index}`,
    skills: index === 13 ? ["TensorFlow"] : [`Unknown${index}`],
  }));
  const ranked = rankTeammates(
      ["Flutter"],
      candidates,
      ["TensorFlow"],
      10,
  );

  assert.equal(ranked.length, 10);
  assert.equal(ranked[0].uid, "candidate-13");
});
