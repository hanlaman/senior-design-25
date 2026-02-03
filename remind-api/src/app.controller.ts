import { Controller, Get } from '@nestjs/common';
import { AllowAnonymous, Session } from '@thallesp/nestjs-better-auth';
import { AppService } from './app.service';
import type { Session as UserSession } from './lib/auth';

@Controller()
export class AppController {
  constructor(private readonly appService: AppService) {}

  @Get()
  @AllowAnonymous()
  getHello(): string {
    return this.appService.getHello();
  }

  @Get('me')
  getProfile(@Session() session: UserSession) {
    return { user: session.user };
  }
}
