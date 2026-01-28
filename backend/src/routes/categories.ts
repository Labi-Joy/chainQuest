import { Router } from 'express'; const router = Router(); router.get('/', (req, res) => res.json({ message: 'categories route working' })); export default router;
