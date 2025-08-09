import { ApiProperty } from '@nestjs/swagger'
import { IsNotEmpty, IsString, Length } from 'class-validator'

export class PasswdCheckDto {
  @ApiProperty({
    description: 'username | phone | email',
    example: 'data-plane-user | 13805718888 | data-plane-user@data-plane.com',
  })
  @IsString()
  @IsNotEmpty()
  @Length(3, 64)
  username: string
}
