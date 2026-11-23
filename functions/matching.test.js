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

test("weights missing skills and complementary team coverage", () => {
  const score = scoreCandidate(
      ["React", "TypeScript"],
      ["Python", "TensorFlow"],
      ["React", "TensorFlow"],
      {
        teamSkills: ["React", "TypeScript"],
        candidate: {preferredRole: "AI Developer"},
      },
  );
  assert.ok(score.score >= 70);
  assert.match(score.reason, /TensorFlow/);
  assert.deepEqual(score.missingSkills, ["TensorFlow"]);
});

test("does not reward a candidate for skills already covered by the team", () => {
  const duplicate = scoreCandidate(
      ["React"],
      ["React", "Vue"],
      ["React"],
      {teamSkills: ["React"]},
  );
  const complementary = scoreCandidate(
      ["React"],
      ["TensorFlow", "Python"],
      ["React"],
      {teamSkills: ["React"]},
  );
  assert.ok(complementary.score > duplicate.score);
});

test("considers project interests, role, experience, and availability", () => {
  const aligned = scoreCandidate(
      [],
      ["Figma", "React"],
      ["React"],
      {
        projectDomains: ["Education", "Accessibility"],
        candidate: {
          interests: ["Education"],
          preferredRole: "Frontend Developer",
          experienceLevel: "Advanced",
          availability: "Available",
        },
      },
  );
  const misaligned = scoreCandidate(
      [],
      ["React"],
      ["React"],
      {
        projectDomains: ["Education"],
        candidate: {
          interests: [],
          preferredRole: "Backend Developer",
          experienceLevel: "Beginner",
          availability: "Unavailable",
        },
      },
  );
  assert.ok(aligned.score > misaligned.score);
  assert.match(aligned.reason, /interests/);
  assert.match(aligned.reason, /Frontend Developer/);
});

test("can reach 100 when all five weighted factors are fully aligned", () => {
  const result = scoreCandidate([], ["React"], ["React"], {
    teamSkills: [],
    projectDomains: ["Education"],
    requiredRoles: ["Frontend Developer"],
    candidate: {
      interests: ["Education"],
      preferredRole: "Frontend Developer",
      experienceLevel: "Expert",
      availability: "Available",
    },
  });
  assert.equal(result.score, 100);
});

test("clamps scores, deduplicates candidates, and applies the result limit", () => {
  const candidates = Array.from({length: 14}, (_, index) => ({
    uid: `candidate-${index}`,
    name: `Candidate ${index}`,
    skills: index === 13 ? ["TensorFlow"] : [`Unknown${index}`],
  }));
  candidates.push(candidates[13]);
  const ranked = rankTeammates(
      ["Flutter"],
      candidates,
      ["TensorFlow"],
      10,
  );

  assert.equal(ranked.length, 10);
  assert.equal(ranked[0].uid, "candidate-13");
  assert.ok(ranked.every((candidate) =>
    candidate.score >= 0 && candidate.score <= 100));
});
