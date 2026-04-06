import { Injectable } from '@nestjs/common';
import { db } from '../db';

@Injectable()
export class ReminderService {
  async create(data: {
    patientId: string;
    type: string;
    title: string;
    notes?: string;
    scheduledTime: string;
    repeatSchedule?: string;
    customDays?: string;
    isEnabled?: boolean;
    sendToWatch?: boolean;
  }) {
    await db
      .insertInto('reminder')
      .values({
        patientId: data.patientId,
        type: data.type,
        title: data.title,
        notes: data.notes ?? null,
        scheduledTime: new Date(data.scheduledTime),
        repeatSchedule: data.repeatSchedule ?? 'once',
        customDays: data.customDays ?? null,
      })
      .execute();

    return { success: true };
  }

  async findAll(patientId: string, date?: string) {
    let query = db
      .selectFrom('reminder')
      .selectAll()
      .where('patientId', '=', patientId);

    if (date) {
      const dayStart = new Date(`${date}T00:00:00`);
      const dayEnd = new Date(`${date}T23:59:59.999`);
      query = query
        .where('scheduledTime', '>=', dayStart)
        .where('scheduledTime', '<=', dayEnd)
        .where('isEnabled', '=', true)
        .where('isCompleted', '=', false);
    }

    return query.orderBy('scheduledTime', 'asc').execute();
  }

  async update(
    id: string,
    data: Partial<{
      type: string;
      title: string;
      notes: string;
      scheduledTime: string;
      repeatSchedule: string;
      customDays: string;
      isEnabled: boolean;
      isCompleted: boolean;
      sendToWatch: boolean;
    }>,
  ) {
    const reminder = await db
      .selectFrom('reminder')
      .select(['patientId'])
      .where('id', '=', id)
      .executeTakeFirst();

    const updateData: Record<string, any> = { updatedAt: new Date() };

    if (data.type !== undefined) updateData.type = data.type;
    if (data.title !== undefined) updateData.title = data.title;
    if (data.notes !== undefined) updateData.notes = data.notes;
    if (data.scheduledTime !== undefined)
      updateData.scheduledTime = new Date(data.scheduledTime);
    if (data.repeatSchedule !== undefined)
      updateData.repeatSchedule = data.repeatSchedule;
    if (data.customDays !== undefined) updateData.customDays = data.customDays;
    if (data.isEnabled !== undefined) updateData.isEnabled = data.isEnabled;
    if (data.isCompleted !== undefined)
      updateData.isCompleted = data.isCompleted;
    if (data.sendToWatch !== undefined)
      updateData.sendToWatch = data.sendToWatch;

    await db
      .updateTable('reminder')
      .set(updateData)
      .where('id', '=', id)
      .execute();

    return { success: true, patientId: reminder?.patientId };
  }

  async remove(id: string) {
    const reminder = await db
      .selectFrom('reminder')
      .select(['patientId'])
      .where('id', '=', id)
      .executeTakeFirst();

    await db.deleteFrom('reminder').where('id', '=', id).execute();
    return { success: true, patientId: reminder?.patientId };
  }

  async markComplete(id: string) {
    const reminder = await db
      .selectFrom('reminder')
      .selectAll()
      .where('id', '=', id)
      .executeTakeFirst();

    if (!reminder) {
      return { success: false, message: 'Reminder not found' };
    }

    const now = new Date();

    if (reminder.repeatSchedule === 'once') {
      await db
        .updateTable('reminder')
        .set({
          isCompleted: true,
          completedAt: now,
          updatedAt: now,
        })
        .where('id', '=', id)
        .execute();
    } else {
      const nextTime = this.calculateNextScheduledTime(
        reminder.scheduledTime,
        reminder.repeatSchedule,
        reminder.customDays,
      );

      await db
        .updateTable('reminder')
        .set({
          scheduledTime: nextTime,
          isCompleted: false,
          completedAt: null,
          lastNotifiedAt: null,
          updatedAt: now,
        })
        .where('id', '=', id)
        .execute();
    }

    return { success: true, patientId: reminder.patientId };
  }

  private calculateNextScheduledTime(
    current: Date,
    schedule: string,
    customDays: string | null,
  ): Date {
    const next = new Date(current);

    if (schedule === 'daily') {
      next.setDate(next.getDate() + 1);
    } else if (schedule === 'weekly') {
      next.setDate(next.getDate() + 7);
    } else if (schedule === 'custom' && customDays) {
      const days = customDays.split(',').map(Number);
      const currentDay = next.getDay();

      // Find next matching day
      let daysToAdd = 0;
      for (let i = 1; i <= 7; i++) {
        const candidateDay = (currentDay + i) % 7;
        if (days.includes(candidateDay)) {
          daysToAdd = i;
          break;
        }
      }

      next.setDate(next.getDate() + (daysToAdd || 7));
    }

    return next;
  }

  async findDueReminders() {
    const now = new Date();
    return db
      .selectFrom('reminder')
      .selectAll()
      .where('isEnabled', '=', true)
      .where('isCompleted', '=', false)
      .where('sendToWatch', '=', true)
      .where('scheduledTime', '<=', now)
      .where((eb) =>
        eb.or([
          eb('lastNotifiedAt', 'is', null),
          eb('lastNotifiedAt', '<', eb.ref('scheduledTime')),
        ]),
      )
      .execute();
  }

  async updateLastNotifiedAt(id: string) {
    await db
      .updateTable('reminder')
      .set({ lastNotifiedAt: new Date() })
      .where('id', '=', id)
      .execute();
  }
}
