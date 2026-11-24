const notificationId = (type, eventId, recipientUid) =>
  `${type}_${eventId}_${recipientUid}`;

const followNotification = ({eventId, followerUid, targetUid}) => ({
  id: notificationId("follow", eventId, targetUid),
  toUid: targetUid,
  fromUid: followerUid,
  type: "follow",
  refId: targetUid,
  read: false,
});

const interestNotification = ({eventId, senderUid, targetUid}) => ({
  id: notificationId("interest", eventId, targetUid),
  toUid: targetUid,
  fromUid: senderUid,
  type: "interest",
  refId: senderUid,
  read: false,
});

const taskNotification = ({eventId, taskId, before, after}) => {
  if (!after ||
      typeof after.assigneeUid !== "string" ||
      typeof after.updatedBy !== "string" ||
      after.assigneeUid === after.updatedBy) {
    return null;
  }

  const changedFields = ["title", "description", "assigneeUid", "status"];
  if (before &&
      !changedFields.some((field) => before[field] !== after[field])) {
    return null;
  }

  return {
    id: notificationId("task", eventId, after.assigneeUid),
    toUid: after.assigneeUid,
    fromUid: after.updatedBy,
    type: "task",
    refId: taskId,
    read: false,
  };
};

const batchInviteNotifications = ({batchId, teacherUid, studentUids}) =>
  [...new Set(studentUids)]
      .filter((uid) => typeof uid === "string" && uid !== teacherUid)
      .map((uid) => ({
        id: `batch_invite_${batchId}_${uid}`,
        toUid: uid,
        fromUid: teacherUid,
        type: "batch_invite",
        refId: batchId,
        read: false,
      }));

module.exports = {
  batchInviteNotifications,
  followNotification,
  interestNotification,
  taskNotification,
};
