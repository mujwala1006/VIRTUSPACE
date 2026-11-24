const test = require("node:test");
const assert = require("node:assert/strict");
const {
  hasVerifiedEmail,
  hasFacultyAccessCode,
  normalizeTeacherRegistration,
  teacherProfileFields,
} = require("./registration_security");
const {
  batchInviteNotifications,
  followNotification,
  interestNotification,
  taskNotification,
} = require("./notification_helpers");

test("teacher registration validates and normalizes required fields", () => {
  assert.deepEqual(normalizeTeacherRegistration({
    name: " Ada Lovelace ",
    department: " Computing ",
    facultyCode: " invite-123 ",
  }), {
    name: "Ada Lovelace",
    department: "Computing",
    facultyCode: "invite-123",
  });
  assert.equal(normalizeTeacherRegistration({
    name: "Ada",
    department: "",
    facultyCode: "invite-123",
  }), null);
});

test("faculty access codes must match exactly and cannot be empty", () => {
  assert.equal(hasFacultyAccessCode("invite-123", "invite-123"), true);
  assert.equal(hasFacultyAccessCode("Invite-123", "invite-123"), false);
  assert.equal(hasFacultyAccessCode("", ""), false);
  assert.equal(hasFacultyAccessCode("invite", null), false);
});

test("only an explicit verified-email claim passes the verification check", () => {
  assert.equal(hasVerifiedEmail({token: {email_verified: true}}), true);
  assert.equal(hasVerifiedEmail({token: {email_verified: false}}), false);
  assert.equal(hasVerifiedEmail({token: {}}), false);
  assert.equal(hasVerifiedEmail(null), false);
});

test("teacher profile uses only fields accepted by the profile schema", () => {
  const profile = teacherProfileFields({
    name: "Ada Lovelace",
    department: "Computing",
  });
  assert.equal(profile.role, "teacher");
  assert.equal(profile.name, "Ada Lovelace");
  assert.equal(profile.department, "Computing");
  assert.equal(profile.resumeUrl, null);
  assert.deepEqual(profile.skills, []);
  assert.equal(profile.followersCount, 0);
  assert.equal(profile.followingCount, 0);
});

test("follow and interest notifications are addressed to the target", () => {
  assert.deepEqual(followNotification({
    eventId: "follow-event",
    followerUid: "follower",
    targetUid: "target",
  }), {
    id: "follow_follow-event_target",
    toUid: "target",
    fromUid: "follower",
    type: "follow",
    refId: "target",
    read: false,
  });
  assert.deepEqual(interestNotification({
    eventId: "interest-event",
    senderUid: "student",
    targetUid: "teacher",
  }), {
    id: "interest_interest-event_teacher",
    toUid: "teacher",
    fromUid: "student",
    type: "interest",
    refId: "student",
    read: false,
  });
});

test("task notifications ignore self-assignment and timestamp-only writes", () => {
  const task = {
    title: "Review",
    description: "Review the draft",
    assigneeUid: "student",
    updatedBy: "teacher",
    status: "todo",
  };
  assert.equal(taskNotification({
    eventId: "event",
    taskId: "task",
    before: task,
    after: {...task},
  }), null);
  assert.equal(taskNotification({
    eventId: "event",
    taskId: "task",
    before: null,
    after: {...task, updatedBy: "student"},
  }), null);
  assert.equal(taskNotification({
    eventId: "event",
    taskId: "task",
    before: task,
    after: {...task, status: "done"},
  }).toUid, "student");
});

test("batch invitations are unique per student and exclude the teacher", () => {
  const notifications = batchInviteNotifications({
    batchId: "batch-1",
    teacherUid: "teacher",
    studentUids: ["student-1", "student-1", "teacher", "student-2"],
  });
  assert.deepEqual(notifications.map((notification) => notification.toUid), [
    "student-1",
    "student-2",
  ]);
  assert.ok(notifications.every((notification) =>
    notification.type === "batch_invite" &&
    notification.fromUid === "teacher"));
});
