import { Router } from 'express'; const router = Router(); router.get('/', (req, res) => res.json({ message: 'verification route working' })); export default router;
