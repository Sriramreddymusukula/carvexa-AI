import { leadService } from '../services/lead.service.js';

export async function createLead(req, res) {
  const result = await leadService.create(req.auth.userId, req.valid.body);
  res.status(201).json({ data: result.lead, emailNotification: result.emailNotification });
}
